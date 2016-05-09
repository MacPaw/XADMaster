#import "CSByteStreamHandle.h"

NSString *CSByteStreamEOFReachedException=@"CSByteStreamEOFReachedException";

@implementation CSByteStreamHandle

/*-(id)initWithName:(NSString *)descname length:(off_t)length
{
	if(self=[super initWithName:descname length:length])
	{
		bytestreamproducebyte_ptr=(uint8_t (*)(id,SEL,off_t))[self methodForSelector:@selector(produceByteAtOffset:)];
	}
	return self;
}*/

-(id)initWithInputBufferForHandle:(CSHandle *)handle length:(off_t)length bufferSize:(int)buffersize;
{
	if(self=[super initWithInputBufferForHandle:handle length:length bufferSize:buffersize])
	{
		bytestreamproducebyte_ptr=(uint8_t (*)(id,SEL,off_t))[self methodForSelector:@selector(produceByteAtOffset:)];
	}
	return self;
}

-(id)initAsCopyOf:(CSByteStreamHandle *)other
{
	[self _raiseNotSupported:_cmd];
	return nil;
}



-(int)streamAtMost:(int)num toBuffer:(void *)buffer
{
	bytesproduced=0;

	if(setjmp(eofenv)==0)
	{
		while(bytesproduced<num)
		{
			uint8_t byte=bytestreamproducebyte_ptr(self,@selector(produceByteAtOffset:),streampos+bytesproduced);
			((uint8_t *)buffer)[bytesproduced++]=byte;
			if(endofstream) break;
		}
	}
	else
	{
		[self endStream];
	}

	return bytesproduced;
}

-(void)resetStream
{
	[self resetByteStream];
}

-(void)resetByteStream {}

-(uint8_t)produceByteAtOffset:(off_t)pos { return 0; }

-(void)endByteStream { [self endStream]; }

@end
