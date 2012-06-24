#import "XADPDFParser.h"
#import "CSMemoryHandle.h"
#import "CSMultiHandle.h"

static int SortPages(id first,id second,void *context);

static CSMemoryHandle *CreateTIFFHeaderWithNumberOfIFDs(int numifds);
static void WriteTIFFShortEntry(CSMemoryHandle *header,int tag,int value);
static void WriteTIFFLongEntry(CSMemoryHandle *header,int tag,int value);
static void WriteTIFFShortArrayEntry(CSMemoryHandle *header,int tag,int numentries,int offset);

@implementation XADPDFParser

+(int)requiredHeaderSize { return 5+48; }

+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name
{
	const uint8_t *bytes=[data bytes];
	int length=[data length];

	if(length<5+48) return NO;

	if(bytes[0]!='%') return NO;
	if(bytes[1]!='P') return NO;
	if(bytes[2]!='D') return NO;
	if(bytes[3]!='F') return NO;
	if(bytes[4]!='-') return NO;

	return YES;
}

-(id)initWithHandle:(CSHandle *)handle name:(NSString *)name
{
	if((self=[super initWithHandle:handle name:name]))
	{
	}
	return self;
}

-(void)dealloc
{
	[super dealloc];
}

-(void)parse
{
	@try
	{
		PDFParser *parser=[PDFParser parserWithHandle:[self handle]];

		[parser parse];

		BOOL isencrypted=[parser needsPassword];
		if(isencrypted)
		{
			if(![parser setPassword:[self password]]) [XADException raisePasswordException];
		}

		// Find image objects in object list
		NSMutableArray *images=[NSMutableArray array];
		NSEnumerator *enumerator=[[parser objectDictionary] objectEnumerator];
		id object;
		while(object=[enumerator nextObject])
		{
			if([object isKindOfClass:[PDFStream class]]&&[object isImage])
			[images addObject:object];
		}

		// Traverse page tree to find which images are referenced from which pages
		NSMutableDictionary *order=[NSMutableDictionary dictionary];
		NSDictionary *root=[parser pagesRoot];
		NSMutableArray *stack=[NSMutableArray arrayWithObject:[[root arrayForKey:@"Kids"] objectEnumerator]];
		int page=0;
		while([stack count])
		{
			id curr=[[stack lastObject] nextObject];
			if(!curr) [stack removeLastObject];
			else
			{
				NSString *type=[curr objectForKey:@"Type"];
				if([type isEqual:@"Pages"])
				{
					[stack addObject:[[curr arrayForKey:@"Kids"] objectEnumerator]];
				}
				else if([type isEqual:@"Page"])
				{
					page++;
					NSDictionary *xobjects=[[curr objectForKey:@"Resources"] objectForKey:@"XObject"];
					NSEnumerator *enumerator=[xobjects objectEnumerator];
					id object;
					while(object=[enumerator nextObject])
					{
						if([object isKindOfClass:[PDFStream class]]&&[object isImage])
						[order setObject:[NSNumber numberWithInt:page] forKey:[object reference]];
					}
				}
				else @throw @"Invalid PDF structure";
			}
		}

		// Sort images in page order.
		[images sortUsingFunction:SortPages context:order];

		// Output images.
		enumerator=[images objectEnumerator];
		PDFStream *image;
		while(image=[enumerator nextObject])
		{
			PDFObjectReference *ref=[image reference];
			NSNumber *page=[order objectForKey:ref];

			NSString *name;
			if(page) name=[NSString stringWithFormat:@"Page %@, object %d",page,[ref number]];
			else name=[NSString stringWithFormat:@"Object %d",[ref number]];

			NSString *imgname=[[image dictionary] objectForKey:@"Name"];
			if(imgname) name=[NSString stringWithFormat:@"%@ (%@)",name,imgname];

			NSNumber *length=[[image dictionary] objectForKey:@"Length"];
			NSArray *decode=[image decodeArray];

			int width=[image imageWidth];
			int height=[image imageHeight];
			int bpc=[image imageBitsPerComponent];

			NSMutableDictionary *dict=[NSMutableDictionary dictionaryWithObjectsAndKeys:
				//[self XADStringWithString:[parser isCompressed]?@"Zlib":@"None"],XADCompressionNameKey,
				length,XADCompressedSizeKey,
				image,@"PDFStream",
			nil];

			if([image isJPEGImage]||[image isJPEG2000Image])
			{
				if([image isJPEGImage])
				{
					name=[name stringByAppendingPathExtension:@"jpg"];
				}
				else
				{
					name=[name stringByAppendingPathExtension:@"jp2"];
				}

				NSString *compname=[self compressionNameForStream:image excludingLast:YES];
				[dict setObject:[self XADStringWithString:compname] forKey:XADCompressionNameKey];

				if(![image hasMultipleFilters] && !isencrypted)
				[dict setObject:length forKey:XADFileSizeKey];

				[dict setObject:@"JPEG" forKey:@"PDFStreamType"];
			}
			else
			{
				CSMemoryHandle *header=nil;
				int bytesperrow=0;

				if([image isGreyImage] || [image isMaskImage])
				{
					header=CreateTIFFHeaderWithNumberOfIFDs(8);
					bytesperrow=(width*bpc+7)/8;

					WriteTIFFShortEntry(header,256,width);
					WriteTIFFShortEntry(header,257,height);
					WriteTIFFShortEntry(header,258,bpc);
					WriteTIFFShortEntry(header,259,1); // Compression

					if([object isMaskImage])
					{
						WriteTIFFShortEntry(header,262,4); // PhotoMetricInterpretation = Mask
					}
					else if(decode)
					{
						float zeropoint=[[decode objectAtIndex:0] floatValue];
						float onepoint=[[decode objectAtIndex:1] floatValue];
						if(zeropoint>onepoint) WriteTIFFShortEntry(header,262,0); // PhotoMetricInterpretation = WhiteIsZero
						else WriteTIFFShortEntry(header,262,1); // PhotoMetricInterpretation = BlackIsZero
					}
					else
					{
						WriteTIFFShortEntry(header,262,1); // PhotoMetricInterpretation = BlackIsZero
					}

					WriteTIFFLongEntry(header,273,8+2+8*12+4); // StripOffsets
					WriteTIFFLongEntry(header,278,height); // RowsPerStrip
					WriteTIFFLongEntry(header,279,bytesperrow*height); // StripByteCounts

					[header writeUInt32LE:0]; // Next IFD offset.
				}
				else if([image isRGBImage] || [image isLabImage])
				{
					header=CreateTIFFHeaderWithNumberOfIFDs(9);
					bytesperrow=(3*width*bpc+7)/8;

					WriteTIFFShortEntry(header,256,width);
					WriteTIFFShortEntry(header,257,height);
					WriteTIFFShortArrayEntry(header,258,3,8+2+9*12+4); // BitsPerSample
					WriteTIFFShortEntry(header,259,1); // Compression

					if([image isRGBImage])
					{
						WriteTIFFShortEntry(header,262,2); // PhotoMetricInterpretation = RGB
					}
					else
					{
						WriteTIFFShortEntry(header,262,8); // PhotoMetricInterpretation = CIELAB
						[self reportInterestingFileWithReason:@"CIELAB image in in PDF"];
					}

					WriteTIFFLongEntry(header,273,8+2+9*12+4+6); // StripOffsets
					WriteTIFFShortEntry(header,277,3); // SamplesPerPixel
					WriteTIFFLongEntry(header,278,height); // RowsPerStrip
					WriteTIFFLongEntry(header,279,bytesperrow*height); // StripByteCounts

					[header writeUInt32LE:0]; // Next IFD offset.

					[header writeUInt16LE:bpc]; // Write BitsPerSample array.
					[header writeUInt16LE:bpc];
					[header writeUInt16LE:bpc];
				}
				else if([image isCMYKImage])
				{
					header=CreateTIFFHeaderWithNumberOfIFDs(10);
					bytesperrow=(4*width*bpc+7)/8;

					WriteTIFFShortEntry(header,256,width);
					WriteTIFFShortEntry(header,257,height);
					WriteTIFFShortArrayEntry(header,258,4,8+2+10*12+4); // BitsPerSample
					WriteTIFFShortEntry(header,259,1); // Compression
					WriteTIFFShortEntry(header,262,5); // PhotoMetricInterpretation = Separated
					WriteTIFFLongEntry(header,273,8+2+10*12+4+8); // StripOffsets
					WriteTIFFShortEntry(header,277,4); // SamplesPerPixel
					WriteTIFFLongEntry(header,278,height); // RowsPerStrip
					WriteTIFFLongEntry(header,279,bytesperrow*height); // StripByteCounts
					WriteTIFFShortEntry(header,322,1); // InkSet = CMYK

					[header writeUInt32LE:0]; // Next IFD offset.

					[header writeUInt16LE:bpc]; // Write BitsPerSample array.
					[header writeUInt16LE:bpc];
					[header writeUInt16LE:bpc];
					[header writeUInt16LE:bpc];
				}
				else if([image isIndexedImage])
				{
					NSString *subcolourspace=[image subColourSpaceOrAlternate];
					if([subcolourspace isEqual:@"DeviceRGB"] || [subcolourspace isEqual:@"CalRGB"])
					{
						int numpalettecolours=[image numberOfColours];
						NSData *palettedata=[image paletteData];

						if(palettedata)
						{
							header=CreateTIFFHeaderWithNumberOfIFDs(9);
							bytesperrow=(width*bpc+7)/8;

							int numtiffcolours=1<<bpc;

							WriteTIFFShortEntry(header,256,width);
							WriteTIFFShortEntry(header,257,height);
							WriteTIFFShortEntry(header,258,bpc);
							WriteTIFFShortEntry(header,259,1); // Compression
							WriteTIFFShortEntry(header,262,3); // PhotoMetricInterpretation = Palette

							WriteTIFFLongEntry(header,273,8+2+9*12+4+6*numtiffcolours); // StripOffsets
							WriteTIFFLongEntry(header,278,height); // RowsPerStrip
							WriteTIFFLongEntry(header,279,bytesperrow*height); // StripByteCounts

							WriteTIFFShortArrayEntry(header,320,3*numtiffcolours,8+2+9*12+4); // StripByteCounts

							[header writeUInt32LE:0]; // Next IFD offset.

							const uint8_t *palettebytes=[palettedata bytes];

							for(int col=0;col<3;col++)
							for(int i=0;i<numtiffcolours;i++)
							{
								if(i<numpalettecolours)
								{
									[header writeUInt16LE:palettebytes[3*i+col]*0x101];
								}
								else
								{
									[header writeUInt16LE:0];
								}
							}
						}
					}
					else if([subcolourspace isEqual:@"DeviceCMYK"] && bpc==8)
					{
						int numpalettecolours=[image numberOfColours];
						NSData *palettedata=[image paletteData];

						if(palettedata)
						{
							header=CreateTIFFHeaderWithNumberOfIFDs(10);
							bytesperrow=4*width;

							WriteTIFFShortEntry(header,256,width);
							WriteTIFFShortEntry(header,257,height);
							WriteTIFFShortArrayEntry(header,258,4,8+2+10*12+4); // BitsPerSample
							WriteTIFFShortEntry(header,259,1); // Compression
							WriteTIFFShortEntry(header,262,5); // PhotoMetricInterpretation = Separated
							WriteTIFFLongEntry(header,273,8+2+10*12+4+8); // StripOffsets
							WriteTIFFShortEntry(header,277,4); // SamplesPerPixel
							WriteTIFFLongEntry(header,278,height); // RowsPerStrip
							WriteTIFFLongEntry(header,279,bytesperrow*height); // StripByteCounts
							WriteTIFFShortEntry(header,322,1); // InkSet = CMYK

							[header writeUInt32LE:0]; // Next IFD offset.

							[header writeUInt16LE:8]; // Write BitsPerSample array.
							[header writeUInt16LE:8];
							[header writeUInt16LE:8];
							[header writeUInt16LE:8];

							[dict setObject:palettedata forKey:@"PDFTIFFPaletteData"];
							[dict setObject:[NSNumber numberWithLongLong:width*height*4] forKey:@"PDFTIFFExpandedLength"];
						}
					}
				}
				else if([image isSeparationImage])
				{
					name=[NSString stringWithFormat:@"%@ (%@)",name,[image separationName]];

					header=CreateTIFFHeaderWithNumberOfIFDs(8);
					bytesperrow=(width*bpc+7)/8;

					WriteTIFFShortEntry(header,256,width);
					WriteTIFFShortEntry(header,257,height);
					WriteTIFFShortEntry(header,258,bpc);
					WriteTIFFShortEntry(header,259,1); // Compression
					WriteTIFFShortEntry(header,262,0); // PhotoMetricInterpretation = WhiteIsZero
					WriteTIFFLongEntry(header,273,8+2+8*12+4); // StripOffsets
					WriteTIFFLongEntry(header,278,height); // RowsPerStrip
					WriteTIFFLongEntry(header,279,bytesperrow*height); // StripByteCounts

					[header writeUInt32LE:0]; // Next IFD offset.
				}

				if(header)
				{
					NSData *headerdata=[header data];
					off_t headersize=[headerdata length];

					NSString *compname=[self compressionNameForStream:image excludingLast:NO];
					[dict setObject:[self XADStringWithString:compname] forKey:XADCompressionNameKey];

					[dict setObject:[NSNumber numberWithLongLong:headersize+bytesperrow*height] forKey:XADFileSizeKey];
					[dict setObject:[NSNumber numberWithLongLong:bytesperrow*height] forKey:@"PDFTIFFDataLength"];
					[dict setObject:[header data] forKey:@"PDFTIFFHeader"];
					[dict setObject:@"TIFF" forKey:@"PDFStreamType"];
				}
			}

			name=[name stringByAppendingPathExtension:@"tiff"];

			[dict setObject:[self XADPathWithString:name] forKey:XADFileNameKey];
			if(isencrypted) [dict setObject:[NSNumber numberWithBool:YES] forKey:XADIsEncryptedKey];

			[self addEntryWithDictionary:dict];
		}
	}
	@catch(id e)
	{
		NSLog(@"Error parsing PDF file %@: %@",[[self handle] name],e);
		[XADException raiseDecrunchException];
	}
}

-(NSString *)compressionNameForStream:(PDFStream *)stream excludingLast:(BOOL)excludelast
{
	NSMutableString *string=[NSMutableString string];

	NSDictionary *dict=[stream dictionary];
	NSArray *filter=[dict arrayForKey:@"Filter"];

	if(filter)
	{
		int count=[filter count];
		if(excludelast) count--;

		for(int i=count-1;i>=0;i--)
		{
			NSString *name=[filter objectAtIndex:i];
			if([name hasSuffix:@"Decode"]) name=[name substringToIndex:[name length]-6];
			if(i!=count-1) [string appendString:@"+"];
			[string appendString:name];
		}
	}

	if(![string length]) return @"None";
	return string;
}

-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum
{
	NSString *streamtype=[dict objectForKey:@"PDFStreamType"];
	PDFStream *stream=[dict objectForKey:@"PDFStream"];

	if([streamtype isEqual:@"JPEG"])
	{
		return [stream JPEGHandle];
	}
	else if([streamtype isEqual:@"TIFF"])
	{
		CSHandle *handle=[stream handle];
		if(!handle) return nil;

		NSNumber *length=[dict objectForKey:@"PDFTIFFDataLength"];
		if(length) handle=[handle nonCopiedSubHandleOfLength:[length longLongValue]];

		NSData *header=[dict objectForKey:@"PDFTIFFHeader"];
		if(!header) return nil;

		NSData *palette=[dict objectForKey:@"PDFTIFFPaletteData"];
		if(palette)
		{
			NSNumber *length=[dict objectForKey:@"PDFTIFFExpandedLength"];
			handle=[[[XAD8BitPaletteExpansionHandle alloc] initWithHandle:handle
			length:[length longLongValue] numberOfChannels:4 palette:palette] autorelease];
		}

		return [CSMultiHandle multiHandleWithHandles:
		[CSMemoryHandle memoryHandleForReadingData:header],handle,nil];
	}
}

-(NSString *)formatName { return @"PDF"; }

@end




static int SortPages(id first,id second,void *context)
{
	NSDictionary *order=(NSDictionary *)context;
	NSNumber *firstpage=[order objectForKey:[first reference]];
	NSNumber *secondpage=[order objectForKey:[second reference]];
	if(!firstpage&&!secondpage) return 0;
	else if(!firstpage) return 1;
	else if(!secondpage) return -1;
	else return [firstpage compare:secondpage];
}

static CSMemoryHandle *CreateTIFFHeaderWithNumberOfIFDs(int numifds)
{
	CSMemoryHandle *header=[CSMemoryHandle memoryHandleForWriting];
	[header writeUInt8:'I']; // Magic number for little-endian TIFF.
	[header writeUInt8:'I'];
	[header writeUInt16LE:42];
	[header writeUInt32LE:8]; // Offset of IFD.
	[header writeUInt16LE:numifds]; // Number of IFD entries.
	return header;
}

static void WriteTIFFShortEntry(CSMemoryHandle *header,int tag,int value)
{
	[header writeUInt16LE:tag];
	[header writeUInt16LE:3];
	[header writeUInt32LE:1];
	[header writeUInt32LE:value];
}


static void WriteTIFFLongEntry(CSMemoryHandle *header,int tag,int value)
{
	[header writeUInt16LE:tag];
	[header writeUInt16LE:4];
	[header writeUInt32LE:1];
	[header writeUInt32LE:value];
}

static void WriteTIFFShortArrayEntry(CSMemoryHandle *header,int tag,int numentries,int offset)
{
	[header writeUInt16LE:tag];
	[header writeUInt16LE:3];
	[header writeUInt32LE:numentries];
	[header writeUInt32LE:offset];
}



@implementation XAD8BitPaletteExpansionHandle

-(id)initWithHandle:(CSHandle *)parent length:(off_t)length
numberOfChannels:(int)numberofchannels palette:(NSData *)palettedata
{
	if((self=[super initWithHandle:parent length:length]))
	{
		palette=[palettedata retain];
		numchannels=numberofchannels;
	}
	return self;
}

-(void)dealloc
{
	[palette release];
	[super dealloc];
}

-(void)resetByteStream
{
	currentchannel=numchannels;
}

-(uint8_t)produceByteAtOffset:(off_t)pos
{
	if(currentchannel>=numchannels)
	{
		const uint8_t *palettebytes=[palette bytes];
		int palettelength=[palette length];

		int pixel=CSInputNextByte(input);

		if(pixel<palettelength/numchannels) memcpy(bytebuffer,&palettebytes[pixel*numchannels],numchannels);
		else memset(bytebuffer,0,numchannels);

		currentchannel=0;
	}

	return bytebuffer[currentchannel++];
}

@end
