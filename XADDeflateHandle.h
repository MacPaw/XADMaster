#import "XADLZSSHandle.h"
#import "XADPrefixCode.h"

@interface XADDeflateHandle:XADLZSSHandle
{
	BOOL deflate64;

	XADPrefixCode *literalcode,*distancecode;
	XADPrefixCode *fixedliteralcode,*fixeddistancecode;
	BOOL storedblock,lastblock;
	int storedcount;
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length;
-(id)initWithHandle:(CSHandle *)handle length:(off_t)length deflate64:(BOOL)deflate64mode;
-(void)dealloc;

-(void)resetLZSSHandle;
-(int)nextLiteralOrOffset:(int *)offset andLength:(int *)length;

-(void)readBlockHeader;
-(XADPrefixCode *)allocAndParseCodeOfSize:(int)size metaCode:(XADPrefixCode *)metacode;
-(XADPrefixCode *)allocAndParseMetaCodeOfSize:(int)size;
-(XADPrefixCode *)fixedLiteralCode;
-(XADPrefixCode *)fixedDistanceCode;

@end
