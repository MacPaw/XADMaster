#import "CSByteStreamHandle.h"
#import "XADPrefixCode.h"

@interface XADSqueezeHandle:CSByteStreamHandle
{
	XADPrefixCode *code;
}

-(id)initWithHandle:(CSHandle *)handle;
-(id)initWithHandle:(CSHandle *)handle length:(off_t)length;

-(void)resetByteStream;
-(uint8_t)produceByteAtOffset:(off_t)pos;

@end
