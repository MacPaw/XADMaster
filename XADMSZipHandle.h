#import "CSBlockStreamHandle.h"
#import "XADCABBlockHandle.h"

@interface XADMSZipHandle:CSBlockStreamHandle
{
	XADCABBlockHandle *blocks;
	uint8_t buffer[32768];
	int lastlength;
}

-(id)initWithHandle:(XADCABBlockHandle *)handle length:(off_t)length;
-(void)dealloc;

-(void)resetBlockStream;
-(int)produceBlockAtOffset:(off_t)pos;

@end
