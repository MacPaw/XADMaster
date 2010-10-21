#import "XADFastLZSSHandle.h"
#import "XADPrefixCode.h"

@interface XADARCDistillHandle:XADFastLZSSHandle
{
	XADPrefixCode *offsetcode;
	int numnodes;
	int nodes[0x274];
}

-(id)initWithHandle:(CSHandle *)handle;
-(id)initWithHandle:(CSHandle *)handle length:(off_t)length;
-(void)dealloc;

-(void)resetLZSSHandle;
-(void)expandFromPosition:(off_t)pos;

@end
