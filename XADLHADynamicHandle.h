#import "XADLZSSHandle.h"
#import "XADPrefixCode.h"

@interface XADLHADynamicHandle:XADLZSSHandle
{
	XADPrefixCode *literalcode,*distancecode;
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length;
-(void)dealloc;

-(void)resetLZSSHandle;
-(int)nextLiteralOrOffset:(int *)offset andLength:(int *)length atPosition:(off_t)pos;

@end
