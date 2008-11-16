#import "CSFilterHandle.h"

NSString *CSFilterEOFReachedException=@"CSFilterEOFReachedException";
NSString *CSFilterInvalidDataException=@"CSFilterInvalidDataException";

@implementation CSFilterHandle

-(id)initWithHandle:(CSHandle *)handle
{
	return [self initWithHandle:handle length:CSHandleMaxLength bufferSize:4096];
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length
{
	return [self initWithHandle:handle length:length bufferSize:4096];
}

-(id)initWithHandle:(CSHandle *)handle bufferSize:(int)buffersize
{
	return [self initWithHandle:handle length:CSHandleMaxLength bufferSize:buffersize];
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length bufferSize:(int)buffersize;
{
	if(self=[super initWithName:[handle name] length:length])
	{
		filterparent=[handle retain];
		filterstartoffs=[handle offsetInFile];
		filterproducebyte_ptr=(uint8_t (*)(id,SEL,off_t))[self methodForSelector:@selector(produceByteAtOffset:)];

		filterbuffer=malloc(buffersize);
		filterbufsize=buffersize;
		filterbufbytes=0;
		currfilterbyte=0;
		currfilterbit=7;
	}
	return self;
}

-(id)initAsCopyOf:(CSFilterHandle *)other
{
	[self _raiseNotSupported:_cmd];
	return nil;
}

-(void)dealloc
{
	[filterparent release];
	free(filterbuffer);
	[super dealloc];
}

-(void)setParentStartOffset:(off_t)offset
{
	filterstartoffs=offset;
}

-(void)seekParentToFileOffset:(off_t)offset
{
	[filterparent seekToFileOffset:offset];
	currfilterbyte=filterbufbytes=0;
	currfilterbit=7;
}

-(int)streamAtMost:(int)num toBuffer:(void *)buffer
{
	int n=0;

	@try
	{
		while(n<num)
		{
			uint8_t byte=filterproducebyte_ptr(self,@selector(produceByteAtOffset:),streampos+n);
			if(endofstream) break;
			((uint8_t *)buffer)[n++]=byte;
		}
	}
	@catch(id e)
	{
		if([e isKindOfClass:[NSException class]]&&[e name]==CSFilterEOFReachedException) endofstream=YES;
		else @throw e;
	}

	return n;
}

-(void)resetStream
{
	[self seekParentToFileOffset:filterstartoffs];
	[self resetFilter];
}

-(void)resetFilter {}

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