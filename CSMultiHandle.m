#import "CSMultiHandle.h"

@implementation CSMultiHandle

+(CSHandle *)multiHandleWithHandleArray:(NSArray *)handlearray
{
	if(!handlearray) return nil;
	int count=[handlearray count];
	if(count==0) return nil;
	else if(count==1) return [handlearray objectAtIndex:0];
	else return [[[self alloc] initWithHandles:handlearray] autorelease];
}

+(CSHandle *)multiHandleWithHandles:(CSHandle *)firsthandle,...
{
	if(!firsthandle) return nil;

	NSMutableArray *array=[NSMutableArray arrayWithObject:firsthandle];
	CSHandle *handle;
	va_list va;

	va_start(va,firsthandle);
	while(handle=va_arg(va,CSHandle *)) [array addObject:handle];
	va_end(va);

	return [self multiHandleWithHandleArray:array];
}


-(id)initWithHandles:(NSArray *)handlearray
{
	if(self=[super initWithName:[NSString stringWithFormat:@"%@, and %d more combined",[[handlearray objectAtIndex:0] name],[handlearray count]-1]])
	{
		handles=[handlearray copy];
		currhandle=0;
	}
	return self;
}

-(id)initAsCopyOf:(CSMultiHandle *)other
{
	if(self=[super initAsCopyOf:other])
	{
		NSMutableArray *handlearray=[NSMutableArray arrayWithCapacity:[other->handles count]];
		NSEnumerator *enumerator=[other->handles objectEnumerator];
		CSHandle *handle;
		while(handle=[enumerator nextObject]) [handlearray addObject:[handle copy]];

		handles=[[NSArray arrayWithArray:handlearray] retain];
		currhandle=other->currhandle;
	}
	return self;
}

-(void)dealloc
{
	[handles release];
	[super dealloc];
}

-(NSArray *)handles { return handles; }

-(off_t)fileSize
{
	off_t size=0;
	NSEnumerator *enumerator=[handles objectEnumerator];
	CSHandle *handle;
	while(handle=[enumerator nextObject]) size+=[handle fileSize];
	return size;
}

-(off_t)offsetInFile
{
	off_t offs=0;
	for(int i=0;i<currhandle;i++) offs+=[[handles objectAtIndex:i] fileSize];
	return offs+[[handles objectAtIndex:currhandle] offsetInFile];
}

-(BOOL)atEndOfFile
{
	return currhandle==[handles count]-1&&[[handles objectAtIndex:currhandle] atEndOfFile];
}

-(void)seekToFileOffset:(off_t)offs
{
	int count=[handles count];

	if(offs==0)
	{
		currhandle=0;
	}
	else
	{
		for(currhandle=0;currhandle<count-1;currhandle++)
		{
			off_t size=[[handles objectAtIndex:currhandle] fileSize];
			if(offs<size) break;
			offs-=size;
		}
	}

	[[handles objectAtIndex:currhandle] seekToFileOffset:offs];
}

-(void)seekToEndOfFile
{
	currhandle=[handles count]-1;
	[(CSHandle *)[handles objectAtIndex:currhandle] seekToEndOfFile];
}

-(int)readAtMost:(int)num toBuffer:(void *)buffer
{
	off_t total=0;
	for(;;)
	{
		off_t actual=[[handles objectAtIndex:currhandle] readAtMost:num-total toBuffer:((char *)buffer)+total];
		total+=actual;
		if(total==num||currhandle==[handles count]-1) return total;
		currhandle++;
		[[handles objectAtIndex:currhandle] seekToFileOffset:0];
	}
}

@end
