#import "CSByteStreamHandle.h"

@interface XADRLE90Handle:CSByteStreamHandle
{
	int repeatedbyte,count;
}

-(id)initWithHandle:(CSHandle *)handle;
-(id)initWithHandle:(CSHandle *)handle length:(off_t)length;

-(void)resetByteStream;
-(uint8_t)produceByteAtOffset:(off_t)pos;

@end
