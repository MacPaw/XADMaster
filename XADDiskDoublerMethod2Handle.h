#import "CSByteStreamHandle.h"

@interface XADDiskDoublerMethod2Handle:CSByteStreamHandle
{
	int numcontexts,currcontext;

	struct
	{
		uint8_t sometable[512];
		uint16_t eventable[256];
		uint16_t oddtable[256];
	} contexts[256];
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length numberOfContexts:(int)num;

-(void)resetByteStream;
-(uint8_t)produceByteAtOffset:(off_t)pos;

-(void)updateContextsForByte:(int)byte;

@end
