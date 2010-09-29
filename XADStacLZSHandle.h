#import "XADFastLZSSHandle.h"
#import "XADPrefixCode.h"

@interface XADStacLZSHandle:XADFastLZSSHandle
{
	XADPrefixCode *lengthcode;
}

-(id)initWithHandle:(CSHandle *)handle;
-(id)initWithHandle:(CSHandle *)handle length:(off_t)length;
-(void)dealloc;

-(void)expandFromPosition:(off_t)pos;

@end
