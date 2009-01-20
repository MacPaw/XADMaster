#import "XADLZSSHandle.h"
#import "XADPrefixCode.h"

@interface XADDeflateHandle:XADLZSSHandle
{
	BOOL deflate64,sitx;

	XADPrefixCode *literalcode,*distancecode;
	XADPrefixCode *fixedliteralcode,*fixeddistancecode;
	BOOL storedblock,lastblock;
	int storedcount;

	int order[19];
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length;
-(id)initWithHandle:(CSHandle *)handle length:(off_t)length deflate64:(BOOL)deflate64mode;
-(id)initWithHandle:(CSHandle *)handle length:(off_t)length deflate64:(BOOL)deflate64mode sitx15:(BOOL)sitxmode;
-(void)dealloc;

-(void)setMetaTableOrder:(const int *)order;

-(void)resetLZSSHandle;
-(int)nextLiteralOrOffset:(int *)offset andLength:(int *)length;

-(void)readBlockHeader;
-(XADPrefixCode *)allocAndParseMetaCodeOfSize:(int)size;
-(XADPrefixCode *)fixedLiteralCode;
-(XADPrefixCode *)fixedDistanceCode;

@end
