#import "CSByteStreamHandle.h"

NSString *CSByteStreamEOFReachedException=@"CSByteStreamEOFReachedException";

@implementation CSByteStreamHandle

-(id)initWithName:(NSString *)descname length:(off_t)length
{
	if(self=[super initWithName:descname length:length])
	{
		bytestreamproducebyte_ptr=(uint8_t (*)(id,SEL,off_t))[self methodForSelector:@selector(produceByteAtOffset:)];
	}
	return self;
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length bufferSize:(int)buffersize;
{
	if(self=[super initWithHandle:handle length:length bufferSize:buffersize])
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
	int n=0;

	@try
	{
		while(n<num)
		{
			uint8_t byte=bytestreamproducebyte_ptr(self,@selector(produceByteAtOffset:),streampos+n);
			((uint8_t *)buffer)[n++]=byte;
			if(endofstream) break;
		}
	}
	@catch(id e)
	{
		if([e isKindOfClass:[NSException class]]
		&&[e name]==CSByteStreamEOFReachedException) endofstream=YES;
		else @throw e;
	}

	return n;
}

-(void)resetStream
{
	CSInputRestart(input);
	[self resetByteStream];
}

-(void)resetByteStream {}

-(uint8_t)produceByteAtOffset:(off_t)pos { return 0; }

@end





/*
@implementation CSFilterHandle

-(id)initWithHandle:(CSHandle *)handle
{
	if(self=[super initWithName:[handle name]])
	{
		parent=[handle retain];
		readatmost_ptr=(int (*)(id,SEL,int,void *))[parent methodForSelector:@selector(readAtMost:toBuffer:)];

		pos=0;

		coro=nil;
		// start couroutine which returns control immediately
	}
	return self;
}

-(id)initAsCopyOf:(CSFilterHandle *)other
{
	parent=nil; coro=nil; [self release];
	[self _raiseNotImplemented:_cmd];
	return nil;
}

-(void)dealloc
{
	[parent release];
	[coro release];
	[super dealloc];
}

-(off_t)offsetInFile { return pos; }

-(int)readAtMost:(int)num toBuffer:(void *)buffer
{
	if(!num) return 0;

	ptr=buffer;
	left=num;

	if(!coro)
	{
		coro=[self newCoroutine];
		[(id)coro filter];
	} else [coro switchTo];

	//if(eof)...

	return num-left;
}

-(void)filter {}

@end

*/
