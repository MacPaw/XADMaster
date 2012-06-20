#import "XADPDFParser.h"
#import "PDF/PDFParser.h"
#import "CSMemoryHandle.h"
#import "CSMultiHandle.h"

static int SortPages(id first,id second,void *context);

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

		if([parser needsPassword])
		{
			if(![parser setPassword:password]) [XADException raisePasswordException];
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
			if(imgname) name=[NSString stringWithFormat:@"%@ (%@)",imgname,name];

			NSNumber *length=[[image dictionary] objectForKey:@"Length"];
			//NSArray *decode=[object decodeArray];
			int bpc=[object bitsPerComponent];

			NSMutableDictionary *dict=[NSMutableDictionary dictionaryWithObjectsAndKeys:
				//[self XADStringWithString:[parser isCompressed]?@"Zlib":@"None"],XADCompressionNameKey,
				length,XADCompressedSizeKey,
				image,@"PDFStream",
			nil];

			if([image isJPEG])
			{
				[dict setObject:length forKey:XADFileSizeKey];
				[dict setObject:[self XADStringWithString:@"None"] forKey:XADCompressionNameKey];
				[dict setObject:@"JPEG" forKey:@"PDFStreamType"];
				name=[name stringByAppendingPathExtension:@"jpg"];
			}
			else if([object isJPEG2000])
			{
				[dict setObject:length forKey:XADFileSizeKey];
				[dict setObject:[self XADStringWithString:@"None"] forKey:XADCompressionNameKey];
				[dict setObject:@"JPEG" forKey:@"PDFStreamType"];
				name=[name stringByAppendingPathExtension:@"jp2"];
				[self reportInterestingFileWithReason:@"JPEG2000 embedded in PDF"];
			}
			else if([object isBitmap]||[object isMask])
			{
			}
			else if((bpc==8||bpc==16)&&[object isGrey])
			{
			}
			else if((bpc==8||bpc==16)&&[object isRGB])
			{
			}
			else if((bpc==8||bpc==16)&&[object isCMYK])
			{
			}
			else if((bpc==8||bpc==16)&&[object isLab])
			{
			}
			else if([object isIndexed])
			{
				NSString *subcolourspace=[object subColourSpaceOrAlternate];
				if([subcolourspace isEqual:@"DeviceRGB"]||[subcolourspace isEqual:@"CalRGB"])
				{
					int colours=[object numberOfColours];
					NSData *palettedata=[object paletteData];

					if(palettedata)
					{
						[dict setObject:[NSNumber numberWithInt:colours] forKey:@"PDFNumberOfColours"];
						[dict setObject:palettedata forKey:@"PDFPaletteData"];
					}
				}
			}

			[dict setObject:[self XADPathWithString:name] forKey:XADFileNameKey];

			[self addEntryWithDictionary:dict];
		}
	}
	@catch(id e)
	{
		NSLog(@"Error parsing PDF file %@: %@",[[self handle] name],e);
		[XADException raiseDecrunchException];
	}

}

-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum
{
	NSString *streamtype=[dict objectForKey:@"PDFStreamType"];
	PDFStream *stream=[dict objectForKey:@"PDFStream"];

	if([streamtype isEqual:@"JPEG"])
	{
		return [stream JPEGHandle];
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




/*

-(XeeImage *)produceImage
{
	NSDictionary *dict=[object dictionary];
	XeeImage *newimage=nil;
	NSArray *decode=[object decodeArray];
	int bpc=[object bitsPerComponent];

	if([object isJPEG])
	{
		CSHandle *subhandle=[object JPEGHandle];
		if(subhandle) newimage=[[[XeeJPEGImage alloc] initWithHandle:subhandle] autorelease];
	}
	else if([object isJPEG2000])
	{
		CSHandle *subhandle=[object JPEGHandle];
		if(subhandle) newimage=[[[XeeImageIOImage alloc] initWithHandle:subhandle] autorelease];
	}
	else if([object isBitmap]||[object isMask])
	{
		CSHandle *subhandle=[object handle];

		newimage=[[[XeeBitmapRawImage alloc] initWithHandle:subhandle
		width:[dict intValueForKey:@"Width" default:0] height:[dict intValueForKey:@"Height" default:0]]
		autorelease];

		if(decode) [(XeeBitmapRawImage *)newimage setZeroPoint:[[decode objectAtIndex:0] floatValue] onePoint:[[decode objectAtIndex:1] floatValue]];
		else [(XeeBitmapRawImage *)newimage setZeroPoint:0 onePoint:1];

		[newimage setDepthBitmap];
	}
	else if((bpc==8||bpc==16)&&[object isGrey])
	{
		CSHandle *subhandle=[object handle];

		if(subhandle) newimage=[[[XeeRawImage alloc] initWithHandle:subhandle
		width:[dict intValueForKey:@"Width" default:0] height:[dict intValueForKey:@"Height" default:0]
		depth:bpc colourSpace:XeeGreyRawColourSpace flags:XeeNoAlphaRawFlag] autorelease];

		if(decode) [(XeeRawImage *)newimage setZeroPoint:[[decode objectAtIndex:0] floatValue] onePoint:[[decode objectAtIndex:1] floatValue] forChannel:0];

		[newimage setDepthGrey:bpc];
		//[newimage setFormat:@"Raw greyscale // TODO - add format names
	}
	else if((bpc==8||bpc==16)&&[object isRGB])
	{
		CSHandle *subhandle=[object handle];

		if(subhandle) newimage=[[[XeeRawImage alloc] initWithHandle:subhandle
		width:[dict intValueForKey:@"Width" default:0] height:[dict intValueForKey:@"Height" default:0]
		depth:bpc colourSpace:XeeRGBRawColourSpace flags:XeeNoAlphaRawFlag] autorelease];

		if(decode)
		{
			[(XeeRawImage *)newimage setZeroPoint:[[decode objectAtIndex:0] floatValue] onePoint:[[decode objectAtIndex:1] floatValue] forChannel:0];
			[(XeeRawImage *)newimage setZeroPoint:[[decode objectAtIndex:2] floatValue] onePoint:[[decode objectAtIndex:3] floatValue] forChannel:1];
			[(XeeRawImage *)newimage setZeroPoint:[[decode objectAtIndex:4] floatValue] onePoint:[[decode objectAtIndex:5] floatValue] forChannel:2];
		}

		[newimage setDepthRGB:bpc];
	}
	else if((bpc==8||bpc==16)&&[object isCMYK])
	{
		CSHandle *subhandle=[object handle];

		if(subhandle) newimage=[[[XeeRawImage alloc] initWithHandle:subhandle
		width:[dict intValueForKey:@"Width" default:0] height:[dict intValueForKey:@"Height" default:0]
		depth:bpc colourSpace:XeeCMYKRawColourSpace flags:XeeNoAlphaRawFlag] autorelease];

		if(decode)
		{
			[(XeeRawImage *)newimage setZeroPoint:[[decode objectAtIndex:0] floatValue] onePoint:[[decode objectAtIndex:1] floatValue] forChannel:0];
			[(XeeRawImage *)newimage setZeroPoint:[[decode objectAtIndex:2] floatValue] onePoint:[[decode objectAtIndex:3] floatValue] forChannel:1];
			[(XeeRawImage *)newimage setZeroPoint:[[decode objectAtIndex:4] floatValue] onePoint:[[decode objectAtIndex:5] floatValue] forChannel:2];
			[(XeeRawImage *)newimage setZeroPoint:[[decode objectAtIndex:6] floatValue] onePoint:[[decode objectAtIndex:7] floatValue] forChannel:3];
		}

		[newimage setDepthCMYK:bpc alpha:NO];
	}
	else if((bpc==8||bpc==16)&&[object isLab])
	{
		CSHandle *subhandle=[object handle];

		if(subhandle) newimage=[[[XeeRawImage alloc] initWithHandle:subhandle
		width:[dict intValueForKey:@"Width" default:0] height:[dict intValueForKey:@"Height" default:0]
		depth:bpc colourSpace:XeeLabRawColourSpace flags:XeeNoAlphaRawFlag] autorelease];

		if(decode)
		{
			[(XeeRawImage *)newimage setZeroPoint:[[decode objectAtIndex:0] floatValue] onePoint:[[decode objectAtIndex:1] floatValue] forChannel:0];
			[(XeeRawImage *)newimage setZeroPoint:[[decode objectAtIndex:2] floatValue] onePoint:[[decode objectAtIndex:3] floatValue] forChannel:1];
			[(XeeRawImage *)newimage setZeroPoint:[[decode objectAtIndex:4] floatValue] onePoint:[[decode objectAtIndex:5] floatValue] forChannel:2];
		}

		[newimage setDepthLab:bpc alpha:NO];
	}
	else if([object isIndexed])
	{
		NSString *subcolourspace=[object subColourSpaceOrAlternate];
		if([subcolourspace isEqual:@"DeviceRGB"]||[subcolourspace isEqual:@"CalRGB"])
		{
			int colours=[object numberOfColours];
			NSData *palettedata=[object paletteData];

			if(palettedata)
			{
				const uint8_t *palettebytes=[palettedata bytes];
				int count=[palettedata length]/3;
				if(count>256) count=256;

				XeePalette *pal=[XeePalette palette];
				for(int i=0;i<count;i++)
				[pal setColourAtIndex:i red:palettebytes[3*i] green:palettebytes[3*i+1] blue:palettebytes[3*i+2]];

				int subwidth=[[dict objectForKey:@"Width"] intValue];
				int subheight=[[dict objectForKey:@"Height"] intValue];
				CSHandle *subhandle=[object handle];

				if(subhandle) newimage=[[[XeeIndexedRawImage alloc] initWithHandle:subhandle
				width:subwidth height:subheight depth:bpc palette:pal] autorelease];
				[newimage setDepthIndexed:colours];
			}
		}
	}

	if(!newimage&&!complained)
	{
		NSLog(@"Unsupported image in PDF: ColorSpace=%@, BitsPerComponent=%@, Filter=%@, DecodeParms=%@",
		[dict objectForKey:@"ColorSpace"],[dict objectForKey:@"BitsPerComponent"],[dict objectForKey:@"Filter"],[dict objectForKey:@"DecodeParms"]);
		complained=YES;
	}

	return newimage;
}


@end
*/

