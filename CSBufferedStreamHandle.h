#import "CSStreamHandle.h"

@interface CSBufferedStreamHandle:CSStreamHandle
{
	uint8_t *streambuffer;
	int streambufsize,streambuflength;
	off_t streambufstart;
}

-(id)initWithName:(NSString *)descname bufferSize:(int)bufsize;
-(id)initWithName:(NSString *)descname length:(off_t)length bufferSize:(int)bufsize;
-(void)dealloc;

-(void)seekToFileOffset:(off_t)offs;

-(void)resetStream;
-(int)streamAtMost:(int)num toBuffer:(void *)buffer;

-(void)resetBufferedStream;
-(int)fillBufferAtOffset:(off_t)pos;

@end
