#import "XADPDFParser.h"
#import "CSMemoryHandle.h"
#import "CSMultiHandle.h"

static int SortPages(id first,id second,void *context);

static NSDictionary *TIFFShortEntry(int tag,int value);
static NSDictionary *TIFFLongEntry(int tag,int value);
static NSDictionary *TIFFLongEntryForImageStart(int tag);
static NSDictionary *TIFFShortArrayEntry(int tag,NSData *data);
static NSDictionary *TIFFUndefinedArrayEntry(int tag,NSData *data);
static NSData *CreateTIFFHeaderWithEntries(NSArray *entries);

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
		[images sortUsingFunction:(void *)SortPages context:order];

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
			NSArray *decode=[image imageDecodeArray];

			int width=[image imageWidth];
			int height=[image imageHeight];
			int bpc=[image imageBitsPerComponent];
			int components=[image numberOfImageComponents];

			NSData *colourprofile=[image imageICCColourProfile];
			int profilesize=0;
			if(colourprofile) profilesize=([colourprofile length]+1)&~1;

			NSMutableDictionary *dict=[NSMutableDictionary dictionaryWithObjectsAndKeys:
				//[self XADStringWithString:[parser isCompressed]?@"Zlib":@"None"],XADCompressionNameKey,
				length,XADCompressedSizeKey,
				image,@"PDFStream",
			nil];

			if([image isJPEGImage]||[image isJPEG2000Image])
			{
				NSString *compname=[self compressionNameForStream:image excludingLast:YES];
				[dict setObject:[self XADStringWithString:compname] forKey:XADCompressionNameKey];

				if(![image hasMultipleFilters] && !isencrypted)
				[dict setObject:length forKey:XADFileSizeKey];

				[dict setObject:@"JPEG" forKey:@"PDFStreamType"];

				if([image isJPEGImage])
				{
					if([[image imageColourSpaceName] isEqual:@"DeviceCMYK"]) colourprofile=[self defaultCMYKProfile];

					if(colourprofile) [dict setObject:colourprofile forKey:@"PDFJPEGColourProfile"];

					name=[name stringByAppendingPathExtension:@"jpg"];
				}
				else
				{
					name=[name stringByAppendingPathExtension:@"jp2"];
				}
			}
			else
			{
				int bytesperrow=(width*bpc*components+7)/8;
				NSData *palettedata=nil;

				int type=[image imageType];
				switch(type)
				{
					case PDFIndexedImageType:
						switch([image imagePaletteType])
						{
							case PDFRGBImageType:
							{
								// Build TIFF palette data.

								int numpalettecolours=[image numberOfImagePaletteColours];
								NSData *pdfpalette=[image imagePaletteData];

								if(pdfpalette)
								{
									int numtiffcolours=1<<bpc;
									uint8_t bytes[3*2*numtiffcolours];
									uint8_t *ptr=bytes;

									const uint8_t *palettebytes=[pdfpalette bytes];

									for(int col=0;col<3;col++)
									for(int i=0;i<numtiffcolours;i++)
									{
										if(i<numpalettecolours)
										{
											CSSetUInt16LE(ptr,palettebytes[3*i+col]*0x101);
										}
										else
										{
											CSSetUInt16LE(ptr,0);
										}
										ptr+=2;
									}

									palettedata=[NSData dataWithBytes:bytes length:sizeof(bytes)];
								}
							}
							break;

							case PDFCMYKImageType:
								// Unpack CMYK palette images if possible.

								if(bpc==8)
								{
									NSData *palettedata=[image imagePaletteData];

									if(palettedata)
									{
										[dict setObject:palettedata forKey:@"PDFTIFFPaletteData"];
										[dict setObject:[NSNumber numberWithLongLong:width*height*4] forKey:@"PDFTIFFExpandedLength"];

										// Override image parameters.
										type=PDFCMYKImageType;
										components=4;
										bytesperrow=4*width;
									}
								}
								else goto giveup;
							break;

							default:
								goto giveup;
						}
					break;

					case PDFSeparationImageType:
					case PDFGrayImageType:
					case PDFRGBImageType:
					case PDFCMYKImageType:
					case PDFMaskImageType:
					case PDFLabImageType:
					break;

					default:
						goto giveup;
				}

				NSMutableArray *entries=[NSMutableArray array];

				[entries addObject:TIFFShortEntry(256,width)];
				[entries addObject:TIFFShortEntry(257,height)];

				if(components==1)
				{
					[entries addObject:TIFFShortEntry(258,bpc)];
				}
				else
				{
					uint8_t bytes[components*2];
					for(int i=0;i<components;i++) CSSetUInt16LE(&bytes[i*2],bpc);
					NSData *data=[NSData dataWithBytes:bytes length:components*2];
					[entries addObject:TIFFShortArrayEntry(258,data)]; // BitsPerSample
				}

				[entries addObject:TIFFShortEntry(259,1)]; // Compression

				switch(type)
				{
					case PDFSeparationImageType:
						[entries addObject:TIFFShortEntry(262,0)]; // PhotoMetricInterpretation = WhiteIsZero
					break;

					case PDFGrayImageType:
						if(decode)
						{
							float zeropoint=[[decode objectAtIndex:0] floatValue];
							float onepoint=[[decode objectAtIndex:1] floatValue];
							if(zeropoint>onepoint) [entries addObject:TIFFShortEntry(262,0)]; // PhotoMetricInterpretation = WhiteIsZero
							else [entries addObject:TIFFShortEntry(262,1)]; // PhotoMetricInterpretation = BlackIsZero
						}
						else
						{
							[entries addObject:TIFFShortEntry(262,1)]; // PhotoMetricInterpretation = BlackIsZero
						}
					break;

					case PDFRGBImageType:
						[entries addObject:TIFFShortEntry(262,2)]; // PhotoMetricInterpretation = RGB
					break;

					case PDFIndexedImageType:
						[entries addObject:TIFFShortEntry(262,3)]; // PhotoMetricInterpretation = Palette
					break;

					case PDFMaskImageType:
						[entries addObject:TIFFShortEntry(262,4)]; // PhotoMetricInterpretation = Mask
					break;

					case PDFCMYKImageType:
						[entries addObject:TIFFShortEntry(262,5)]; // PhotoMetricInterpretation = Separated
					break;

					case PDFLabImageType:
						[entries addObject:TIFFShortEntry(262,8)]; // PhotoMetricInterpretation = CIELAB
					break;
				}

				[entries addObject:TIFFLongEntryForImageStart(273)]; // StripOffsets
				if(components>1) [entries addObject:TIFFShortEntry(277,components)]; // SamplesPerPixel
				[entries addObject:TIFFLongEntry(278,height)]; // RowsPerStrip
				[entries addObject:TIFFLongEntry(279,bytesperrow*height)]; // StripByteCounts

				if(palettedata) [entries addObject:TIFFShortArrayEntry(320,palettedata)]; // Palette
				if(type==PDFCMYKImageType) [entries addObject:TIFFShortEntry(332,1)]; // InkSet = CMYK
				if(colourprofile) [entries addObject:TIFFUndefinedArrayEntry(0x8773,colourprofile)];

				NSData *headerdata=CreateTIFFHeaderWithEntries(entries);
				off_t headersize=[headerdata length];

				NSString *compname=[self compressionNameForStream:image excludingLast:NO];
				[dict setObject:[self XADStringWithString:compname] forKey:XADCompressionNameKey];

				[dict setObject:[NSNumber numberWithLongLong:headersize+bytesperrow*height] forKey:XADFileSizeKey];
				[dict setObject:[NSNumber numberWithLongLong:bytesperrow*height] forKey:@"PDFTIFFDataLength"];
				[dict setObject:headerdata forKey:@"PDFTIFFHeader"];
				[dict setObject:entries forKey:@"PDFTIFFHeaderEntries"];
				[dict setObject:@"TIFF" forKey:@"PDFStreamType"];

				name=[name stringByAppendingPathExtension:@"tiff"];
			}

			giveup:
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

-(NSData *)defaultCMYKProfile
{
	return [NSData dataWithContentsOfFile:@"/System/Library/ColorSync/Profiles/Generic CMYK Profile.icc"];
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
	else
	{
		return nil;
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

static NSDictionary *TIFFShortEntry(int tag,int value)
{
	return [NSDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithInt:tag],@"Tag",
		[NSNumber numberWithInt:3],@"Type",
		[NSNumber numberWithInt:1],@"Count",
		[NSNumber numberWithInt:value],@"Value",
	nil];
}


static NSDictionary *TIFFLongEntry(int tag,int value)
{
	return [NSDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithInt:tag],@"Tag",
		[NSNumber numberWithInt:4],@"Type",
		[NSNumber numberWithInt:1],@"Count",
		[NSNumber numberWithInt:value],@"Value",
	nil];
}

static NSDictionary *TIFFLongEntryForImageStart(int tag)
{
	return [NSDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithInt:tag],@"Tag",
		[NSNumber numberWithInt:4],@"Type",
		[NSNumber numberWithInt:1],@"Count",
	nil];
}

static NSDictionary *TIFFShortArrayEntry(int tag,NSData *data)
{
	return [NSDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithInt:tag],@"Tag",
		[NSNumber numberWithInt:3],@"Type",
		[NSNumber numberWithInt:[data length]/2],@"Count",
		data,@"Data",
	nil];
}

static NSDictionary *TIFFUndefinedArrayEntry(int tag,NSData *data)
{
	return [NSDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithInt:tag],@"Tag",
		[NSNumber numberWithInt:7],@"Type",
		[NSNumber numberWithInt:[data length]],@"Count",
		data,@"Data",
	nil];
}

static NSData *CreateTIFFHeaderWithEntries(NSArray *entries)
{
	CSMemoryHandle *header=[CSMemoryHandle memoryHandleForWriting];

	// Write TIFF header.
	[header writeUInt8:'I']; // Magic number for little-endian TIFF.
	[header writeUInt8:'I'];
	[header writeUInt16LE:42];
	[header writeUInt32LE:8]; // Offset of IFD.

	// Write IFD header.
	[header writeUInt16LE:[entries count]]; // Number of IFD entries.

	uint32_t dataoffset=8+2+[entries count]*12+4;
	uint32_t datasize=0;

	NSEnumerator *enumerator;
	NSDictionary *entry;

	// Calculate total data size.
	enumerator=[entries objectEnumerator];
	while((entry=[enumerator nextObject]))
	{
		NSData *data=[entry objectForKey:@"Data"];
		int length=[data length];
		datasize+=(length+1)&~1;
	}

	uint32_t imagestart=dataoffset+datasize;

	// Write IFD entries.
	enumerator=[entries objectEnumerator];
	while((entry=[enumerator nextObject]))
	{
		NSNumber *tag=[entry objectForKey:@"Tag"];
		NSNumber *type=[entry objectForKey:@"Type"];
		NSNumber *count=[entry objectForKey:@"Count"];

		[header writeUInt16LE:[tag intValue]];
		[header writeUInt16LE:[type intValue]];
		[header writeUInt32LE:[count unsignedIntValue]];

		if([count intValue]==1)
		{
			NSNumber *value=[entry objectForKey:@"Value"];
			if(value) [header writeUInt32LE:[value unsignedIntValue]];
			else [header writeUInt32LE:imagestart];
		}
		else
		{
			NSData *data=[entry objectForKey:@"Data"];
			[header writeUInt32LE:dataoffset];

			int length=[data length];
			dataoffset+=(length+1)&~1;
		}
	}

	// Write IFD footer.
	[header writeUInt32LE:0]; // Next IFD offset.

	// Write data segments.
	enumerator=[entries objectEnumerator];
	while((entry=[enumerator nextObject]))
	{
		NSData *data=[entry objectForKey:@"Data"];
		[header writeData:data];
		if([data length]&1) [header writeUInt8:0];
	}

	return [header data];
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
