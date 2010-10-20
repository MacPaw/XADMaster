#import "CSByteStreamHandle.h"

@interface XADSqueezeHandle:CSByteStreamHandle
{
	int nodes[257*2];
}

-(void)resetByteStream;
-(uint8_t)produceByteAtOffset:(off_t)pos;

@end
