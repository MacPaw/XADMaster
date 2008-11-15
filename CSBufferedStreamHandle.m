#import "CSBufferedStreamHandle.h"

static inline int imin(int a,int b) { return a<b?a:b; }

@implementation CSBufferedStreamHandle


-(id)initWithName:(NSString *)descname bufferSize:(int)bufsize
{
	return [self initWithName:descname length:CSHandleMaxLength bufferSize:CSHandleMaxLength];
}

-(id)initWithName:(NSString *)descname length:(off_t)length bufferSize:(int)bufsize
{
	if(self=[super initWithName:descname length:length])
	{
		streambufsize=bufsize;
		streambuffer=malloc(bufsize);
		streambuflength=0;
		streambufstart=0;
	}
	return self;
}

-(void)dealloc
{
	free(streambuffer);
	[super dealloc];
}

-(void)seekToFileOffset:(off_t)offs
{
	if(offs>=streambufstart&&offs<streambufstart+streambuflength)
	{
		streampos=offs;
	}
	else
	{
		if(offs>=streambufstart+streambuflength) streampos+=streambuflength;
		[super seekToFileOffset:offs];
	}
}

-(void)resetStream
{
	streambuflength=0;
	streambufstart=0;
	[self resetBufferedStream];
}

-(int)streamAtMost:(int)num toBuffer:(void *)buffer
{
	int n=0;

	if(streampos>=streambufstart&&streampos<streambufstart+streambuflength)
	{
		int offs=streampos-streambufstart;
		int count=streambuflength-offs;
		if(count>num) count=num;
		memcpy(buffer,streambuffer+offs,count);
		n+=count;
	}

	while(n<num)
	{
		int produced=[self fillBufferAtOffset:streampos+n];

		int count=imin(produced,num-n);
		memcpy(buffer+n,streambuffer,count);
		n+=count;

		if(produced<streambufsize) break;
	}

	return n;
}

-(void)resetBufferedStream { }

-(int)fillBufferAtOffset:(off_t)pos { return 0; }

@end
