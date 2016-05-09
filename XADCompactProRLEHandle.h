#import "CSByteStreamHandle.h"


@interface XADCompactProRLEHandle:CSByteStreamHandle
{
	int saved,repeat;
	BOOL halfescaped;
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length;

-(void)resetByteStream;
-(uint8_t)produceByteAtOffset:(off_t)pos;

@end
