#import <Foundation/Foundation.h>

#import "NSDictionaryNumberExtension.h"

#import "../CSHandle.h"
#import "../CSByteStreamHandle.h"

@class PDFParser,PDFObjectReference;

@interface PDFStream:NSObject
{
	NSDictionary *dict;
	CSHandle *fh;
	off_t offs;
	PDFObjectReference *ref;
	PDFParser *parser;
}

-(id)initWithDictionary:(NSDictionary *)dictionary fileHandle:(CSHandle *)filehandle
reference:(PDFObjectReference *)reference parser:(PDFParser *)owner;
-(void)dealloc;

-(NSDictionary *)dictionary;
-(PDFObjectReference *)reference;

-(BOOL)isImage;
-(BOOL)isJPEGImage;
-(BOOL)isJPEG2000Image;
-(BOOL)isMaskImage;
-(BOOL)isBitmapImage;
-(BOOL)isIndexedImage;
-(BOOL)isGreyImage;
-(BOOL)isRGBImage;
-(BOOL)isCMYKImage;
-(BOOL)isLabImage;
-(BOOL)isSeparationImage;

-(int)imageWidth;
-(int)imageHeight;
-(int)imageBitsPerComponent;

-(NSString *)colourSpaceOrAlternate;
-(NSString *)subColourSpaceOrAlternate;
-(NSString *)_parseColourSpace:(id)colourspace;
-(int)numberOfColours;
-(NSData *)paletteData;
-(NSArray *)decodeArray;
-(NSString *)separationName;

-(BOOL)hasMultipleFilters;
-(NSString *)finalFilter;

-(CSHandle *)rawHandle;
-(CSHandle *)handle;
-(CSHandle *)JPEGHandle;
-(CSHandle *)handleExcludingLast:(BOOL)excludelast;
-(CSHandle *)handleForFilterName:(NSString *)filtername decodeParms:(NSDictionary *)decodeparms parentHandle:(CSHandle *)parent;
-(CSHandle *)predictorHandleForDecodeParms:(NSDictionary *)decodeparms parentHandle:(CSHandle *)parent;

-(NSString *)description;

@end

@interface PDFASCII85Handle:CSByteStreamHandle
{
	uint32_t val;
	BOOL finalbytes;
}

-(void)resetByteStream;
-(uint8_t)produceByteAtOffset:(off_t)pos;

@end

@interface PDFHexHandle:CSByteStreamHandle
{
}

-(uint8_t)produceByteAtOffset:(off_t)pos;

@end




@interface PDFTIFFPredictorHandle:CSByteStreamHandle
{
	int cols,comps,bpc;
	int prev[4];
}

-(id)initWithHandle:(CSHandle *)handle columns:(int)columns
components:(int)components bitsPerComponent:(int)bitspercomp;
-(uint8_t)produceByteAtOffset:(off_t)pos;

@end

@interface PDFPNGPredictorHandle:CSByteStreamHandle
{
	int cols,comps,bpc;
	uint8_t *prevbuf;
	int type;
}

-(id)initWithHandle:(CSHandle *)handle columns:(int)columns
components:(int)components bitsPerComponent:(int)bitspercomp;
-(void)resetByteStream;
-(uint8_t)produceByteAtOffset:(off_t)pos;

@end

