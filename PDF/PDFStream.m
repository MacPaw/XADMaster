#import "PDFStream.h"
#import "PDFParser.h"
#import "PDFEncryptionHandler.h"

#import "CCITTHandle.h"
#import "LZWHandle.h"

#import "../CSZlibHandle.h"
#import "../CSMemoryHandle.h"
#import "../CSMultiHandle.h"



@implementation PDFStream

-(id)initWithDictionary:(NSDictionary *)dictionary fileHandle:(CSHandle *)filehandle
reference:(PDFObjectReference *)reference parser:(PDFParser *)owner
{
	if(self=[super init])
	{
		dict=[dictionary retain];
		fh=[filehandle retain];
		offs=[fh offsetInFile];
		ref=[reference retain];
		parser=owner;
	}
	return self;
}

-(void)dealloc
{
	[dict release];
	[fh release];
	[ref release];
	[super dealloc];
}




-(NSDictionary *)dictionary { return dict; }

-(PDFObjectReference *)reference { return ref; }



-(BOOL)isImage
{
	NSString *type=[dict objectForKey:@"Type"];
	NSString *subtype=[dict objectForKey:@"Subtype"];
	return (!type||[type isEqual:@"XObject"])&&subtype&&[subtype isEqual:@"Image"]; // kludge for broken Ghostscript PDFs
}

-(BOOL)isJPEGImage
{
	return [[self finalFilter] isEqual:@"DCTDecode"]&&[self imageBitsPerComponent]==8;
}

-(BOOL)isJPEG2000Image
{
	return [[self finalFilter] isEqual:@"JPXDecode"];
}

-(BOOL)isMaskImage
{
	return [dict boolValueForKey:@"ImageMask" default:NO]&&[self imageBitsPerComponent]==1;
}

-(BOOL)isBitmapImage
{
	return [self isGreyImage]&&[self imageBitsPerComponent]==1;
}

-(BOOL)isIndexedImage
{
	NSString *colourspace=[self colourSpaceOrAlternate];
	return [colourspace isEqual:@"Indexed"];
}

-(BOOL)isGreyImage
{
	NSString *colourspace=[self colourSpaceOrAlternate];
	return [colourspace isEqual:@"DeviceGray"]||[colourspace isEqual:@"CalGray"];
}

-(BOOL)isRGBImage
{
	NSString *colourspace=[self colourSpaceOrAlternate];
	return [colourspace isEqual:@"DeviceRGB"]||[colourspace isEqual:@"CalRGB"];
}

-(BOOL)isCMYKImage
{
	NSString *colourspace=[self colourSpaceOrAlternate];
	return [colourspace isEqual:@"DeviceCMYK"];
}

-(BOOL)isLabImage
{
	NSString *colourspace=[self colourSpaceOrAlternate];
	return [colourspace isEqual:@"Lab"];
}

-(BOOL)isSeparationImage
{
	NSString *colourspace=[self colourSpaceOrAlternate];
	return [colourspace isEqual:@"Separation"];
}




-(int)imageWidth
{
	return [dict intValueForKey:@"Width" default:0];
}

-(int)imageHeight
{
	return [dict intValueForKey:@"Height" default:0];
}

-(int)imageBitsPerComponent
{
	return [dict intValueForKey:@"BitsPerComponent" default:0];
}




-(NSString *)colourSpaceOrAlternate
{
	id colourspace=[dict objectForKey:@"ColorSpace"];
	if(!colourspace) return nil;

	return [self _parseColourSpace:colourspace];
}

-(NSString *)subColourSpaceOrAlternate
{
	id colourspace=[dict objectForKey:@"ColorSpace"];
	if(!colourspace) return nil;

	if(![colourspace isKindOfClass:[NSArray class]]) return nil;
	if([colourspace count]!=4) return nil;
	if(![[colourspace objectAtIndex:0] isEqual:@"Indexed"]) return nil;

	return [self _parseColourSpace:[colourspace objectAtIndex:1]];
}

-(NSString *)_parseColourSpace:(id)colourspace
{
	if([colourspace isKindOfClass:[NSString class]]) return colourspace;
	else if([colourspace isKindOfClass:[NSArray class]])
	{
		int count=[colourspace count];
		if(count<1) return nil;

		NSString *name=[colourspace objectAtIndex:0];
		if([name isEqual:@"ICCBased"])
		{
			if(count<2) return nil;

			PDFStream *def=[colourspace objectAtIndex:1];
			if(![def isKindOfClass:[PDFStream class]]) return nil;

			NSString *alternate=[[def dictionary] objectForKey:@"Alternate"];
			if(alternate) return alternate;

			int n=[[def dictionary] intValueForKey:@"N" default:0];
			switch(n)
			{
				case 1: return @"DeviceGray";
				case 3: return @"DeviceRGB";
				case 4: return @"DeviceCMYK";
				default: return nil;
			}
		}
		else return name;
	}
	else return nil;
}

-(int)numberOfColours
{
	id colourspace=[dict objectForKey:@"ColorSpace"];
	if(!colourspace) return 0;

	if(![colourspace isKindOfClass:[NSArray class]]) return 0;
	if([colourspace count]!=4) return 0;
	if(![[colourspace objectAtIndex:0] isEqual:@"Indexed"]) return 0;

	return [[colourspace objectAtIndex:2] intValue]+1;
}

-(NSData *)paletteData
{
	id colourspace=[dict objectForKey:@"ColorSpace"];
	if(!colourspace) return nil;

	if(![colourspace isKindOfClass:[NSArray class]]) return nil;
	if([colourspace count]!=4) return nil;
	if(![[colourspace objectAtIndex:0] isEqual:@"Indexed"]) return nil;

	NSString *subcolourspace=[self subColourSpaceOrAlternate];

	int numchannels;
	if([subcolourspace isEqual:@"DeviceRGB"] || [subcolourspace isEqual:@"CalRGB"]) numchannels=3;
	else if([subcolourspace isEqual:@"DeviceCMYK"]) numchannels=4;
	else return nil;

	int numcolours=[[colourspace objectAtIndex:2] intValue]+1;

	id palette=[colourspace objectAtIndex:3];

	NSData *data;
	if([palette isKindOfClass:[PDFStream class]]) data=[[palette handle] remainingFileContents];
	else if([palette isKindOfClass:[PDFString class]]) data=[palette data];
	else return nil;

	if(!data) return nil;
	if([data length]<numchannels*numcolours) return nil;

	return data;
}

-(NSArray *)decodeArray
{
	id decode=[dict objectForKey:@"Decode"];
	if(!decode) return nil;

	if(![decode isKindOfClass:[NSArray class]]) return nil;

	int n;
	if([self isGreyImage]||[self isMaskImage]) n=1;
	else if([self isRGBImage]||[self isLabImage]) n=3;
	else if([self isCMYKImage]) n=4;
	else return nil;
	if([decode count]!=n*2) return nil;

	return decode;
}

-(NSString *)separationName
{
	id colourspace=[dict objectForKey:@"ColorSpace"];
	if(!colourspace) return nil;

	if(![colourspace isKindOfClass:[NSArray class]]) return nil;

	int count=[colourspace count];
	if(count<2) return nil;

	NSString *name=[colourspace objectAtIndex:0];
	if(![name isEqual:@"Separation"]) return nil;

	return [colourspace objectAtIndex:1];
}



-(BOOL)hasMultipleFilters
{
	id filter=[dict objectForKey:@"Filter"];

	if(!filter) return NO;
	else if([filter isKindOfClass:[NSArray class]]) return [filter count]>1;
	else return NO;
}

-(NSString *)finalFilter
{
	id filter=[dict objectForKey:@"Filter"];

	if(!filter) return NO;
	else if([filter isKindOfClass:[NSArray class]]) return [filter lastObject];
	else return filter;
}




-(CSHandle *)rawHandle
{
	return [fh subHandleFrom:offs length:[dict intValueForKey:@"Length" default:0]];
}

-(CSHandle *)handle
{
	return [self handleExcludingLast:NO];
}

-(CSHandle *)JPEGHandle
{
//NSLog(@"%@",dict);
	return [self handleExcludingLast:YES];
}

-(CSHandle *)handleExcludingLast:(BOOL)excludelast
{
	CSHandle *handle;
	PDFEncryptionHandler *encryption=[parser encryptionHandler];

	if(encryption) handle=[encryption decryptStream:self];
	else handle=[self rawHandle];

	NSArray *filter=[dict arrayForKey:@"Filter"];
	NSArray *decodeparms=[dict arrayForKey:@"DecodeParms"];

	if(filter)
	{
		int count=[filter count];
		if(excludelast) count--;

		for(int i=0;i<count;i++)
		{
			handle=[self handleForFilterName:[filter objectAtIndex:i]
			decodeParms:[decodeparms objectAtIndex:i] parentHandle:handle];
			if(!handle) return nil;
		}
	}

	return handle;
}

-(CSHandle *)handleForFilterName:(NSString *)filtername decodeParms:(NSDictionary *)decodeparms parentHandle:(CSHandle *)parent
{
	if(!decodeparms) decodeparms=[NSDictionary dictionary];

	if([filtername isEqual:@"FlateDecode"])
	{
		return [self predictorHandleForDecodeParms:decodeparms
		parentHandle:[CSZlibHandle zlibHandleWithHandle:parent]];
	}
	else if([filtername isEqual:@"CCITTFaxDecode"])
	{
		int k=[decodeparms intValueForKey:@"K" default:0];
		int cols=[decodeparms intValueForKey:@"Columns" default:1728];
		int white=[decodeparms intValueForKey:@"BlackIs1" default:NO]?0:1;

		if(k==0) return nil;
		else if(k>0) return nil;
//		if(k==0) return [[[CCITTFaxT41DHandle alloc] initWithHandle:parent columns:cols white:white] autorelease];
//		else if(k>0) return [[[CCITTFaxT42DHandle alloc] initWithHandle:parent columns:cols white:white] autorelease];
		else return [[[CCITTFaxT6Handle alloc] initWithHandle:parent columns:cols white:white] autorelease];
	}
	else if([filtername isEqual:@"LZWDecode"])
	{
		int early=[decodeparms intValueForKey:@"EarlyChange" default:1];
		return [self predictorHandleForDecodeParms:decodeparms
		parentHandle:[[[LZWHandle alloc] initWithHandle:parent earlyChange:early] autorelease]];
	}
	else if([filtername isEqual:@"ASCII85Decode"])
	{
		return [[[PDFASCII85Handle alloc] initWithHandle:parent] autorelease];
	}
	else if([filtername isEqual:@"Crypt"]) return parent; // handled elsewhere

	return nil;
}

-(CSHandle *)predictorHandleForDecodeParms:(NSDictionary *)decodeparms parentHandle:(CSHandle *)parent
{
	NSNumber *predictor=[decodeparms objectForKey:@"Predictor"];
	if(!predictor) return parent;

	int pred=[predictor intValue];
	if(pred==1) return parent;

	NSNumber *columns=[decodeparms objectForKey:@"Columns"];
	NSNumber *colors=[decodeparms objectForKey:@"Colors"];
	NSNumber *bitspercomponent=[decodeparms objectForKey:@"BitsPerComponent"];

	int cols=columns?[columns intValue]:1;
	int comps=colors?[colors intValue]:1;
	int bpc=bitspercomponent?[bitspercomponent intValue]:8;

	if(pred==2) return [[[PDFTIFFPredictorHandle alloc] initWithHandle:parent columns:cols components:comps bitsPerComponent:bpc] autorelease];
	else if(pred>=10&&pred<=15) return [[[PDFPNGPredictorHandle alloc] initWithHandle:parent columns:cols components:comps bitsPerComponent:bpc] autorelease];
	else [NSException raise:@"PDFStreamPredictorException" format:@"PDF Predictor %d not supported",pred];
	return nil;
}





-(NSString *)description { return [NSString stringWithFormat:@"<Stream with dictionary: %@>",dict]; }

@end




@implementation PDFASCII85Handle

-(void)resetByteStream
{
	finalbytes=0;
}

static uint8_t ASCII85NextByte(CSInputBuffer *input)
{
	uint8_t b;
	do { b=CSInputNextByte(input); }
	while(!((b>=33&&b<=117)||b=='z'||b=='~'));
	return b;
}

-(uint8_t)produceByteAtOffset:(off_t)pos
{
	int byte=pos&3;
	if(byte==0)
	{
		uint8_t c1=ASCII85NextByte(input);

		if(c1=='z') val=0;
		else if(c1=='~') CSByteStreamEOF(self);
		else
		{
			uint8_t c2,c3,c4,c5;

			c2=ASCII85NextByte(input);
			if(c2!='~')
			{
				c3=ASCII85NextByte(input);
				if(c3!='~')
				{
					c4=ASCII85NextByte(input);
					if(c4!='~')
					{
						c5=ASCII85NextByte(input);
						if(c5=='~') { c5=33; finalbytes=3; }
					}
					else { c4=c5=33; finalbytes=2; }
				}
				else { c3=c4=c5=33; finalbytes=1; }
			}
			else CSByteStreamEOF(self);

			val=((((c1-33)*85+c2-33)*85+c3-33)*85+c4-33)*85+c5-33;
		}
		return val>>24;
	}
	else
	{
		if(finalbytes&&byte>=finalbytes) CSByteStreamEOF(self);
		return val>>24-byte*8;
	}
}

@end




@implementation PDFTIFFPredictorHandle

-(id)initWithHandle:(CSHandle *)handle columns:(int)columns
components:(int)components bitsPerComponent:(int)bitspercomp
{
	if(self=[super initWithHandle:handle])
	{
		cols=columns;
		comps=components;
		bpc=bitspercomp;
		if(bpc!=8) [NSException raise:@"PDFTIFFPredictorException" format:@"Bit depth %d not supported for TIFF predictor",bpc];
		if(comps>4||comps<1) [NSException raise:@"PDFTIFFPredictorException" format:@"Color count %d not supported for TIFF predictor",bpc];
	}
	return self;
}

-(uint8_t)produceByteAtOffset:(off_t)pos
{
	if(bpc==8)
	{
		int comp=pos%comps;
		if((pos/comps)%cols==0) prev[comp]=CSInputNextByte(input);
		else prev[comp]+=CSInputNextByte(input);
		return prev[comp];
	}
	return 0;
}

@end



static inline int iabs(int a) { return a>=0?a:-a; }

@implementation PDFPNGPredictorHandle

-(id)initWithHandle:(CSHandle *)handle columns:(int)columns
components:(int)components bitsPerComponent:(int)bitspercomp
{
	if(self=[super initWithHandle:handle])
	{
		cols=columns;
		comps=components;
		bpc=bitspercomp;
		if(bpc<8) comps=1;
		if(bpc>8) [NSException raise:@"PDFPNGPredictorException" format:@"Bit depth %d not supported for PNG predictor",bpc];

		prevbuf=malloc(cols*comps+2*comps);
	}
	return self;
}

-(void)dealloc
{
	free(prevbuf);
	[super dealloc];
}

-(void)resetByteStream
{
	memset(prevbuf,0,cols*comps+2*comps);
}

-(uint8_t)produceByteAtOffset:(off_t)pos
{
	if(bpc<=8)
	{
		int row=pos/(cols*comps);
		int col=pos%(cols*comps);
		int buflen=cols*comps+2*comps;
		int bufoffs=((col-comps*row)%buflen+buflen)%buflen;

		if(col==0)
		{
			type=CSInputNextByte(input);
			for(int i=0;i<comps;i++) prevbuf[(i+cols*comps+comps+bufoffs)%buflen]=0;
		}

		int x=CSInputNextByte(input);
		int a=prevbuf[(cols*comps+comps+bufoffs)%buflen];
		int b=prevbuf[(comps+bufoffs)%buflen];
		int c=prevbuf[bufoffs];
		int val;

		switch(type)
		{
			case 0: val=x; break;
			case 1: val=x+a; break;
			case 2: val=x+b; break;
			case 3: val=x+(a+b)/2; break;
			case 4:
			{
				int p=a+b-c;
				int pa=iabs(p-a);
				int pb=iabs(p-b);
				int pc=iabs(p-c);

				if(pa<=b&&pa<=pc) val=pa;
				else if(pb<=pc) val=pb;
				else val=pc;
			}
			break;
		}

		prevbuf[bufoffs]=val;
		return val;
	}
	return 0;
}

@end

