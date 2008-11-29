#import "XADLZSSHandle.h"
#import "XADPrefixCode.h"

@interface XADDeflateHandle:XADLZSSHandle
{
	XADPrefixCode *literalcode,*offsetcode;
	int storedcount;
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length windowSize:(int)windowsize;
-(void)dealloc;

-(void)resetLZSSHandle;
-(int)nextLiteralOrOffset:(int *)offset andLength:(int *)length;

-(void)readBlockHeader;
-(XADPrefixCode *)allocAndParseCodeOfSize:(int)size metaCode:(XADPrefixCode *)metacode;
-(XADPrefixCode *)allocAndParseMetaCodeOfSize:(int)size;
-(XADPrefixCode *)fixedLiteralCode;
-(XADPrefixCode *)fixedDistanceCode;

@end
