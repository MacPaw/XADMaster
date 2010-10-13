#import "CSByteStreamHandle.h"

@interface XADRLE90Handle:CSByteStreamHandle
{
	int byte,count;
}

-(void)resetByteStream;
-(uint8_t)produceByteAtOffset:(off_t)pos;

@end
