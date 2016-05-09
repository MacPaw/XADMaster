#import "CSMultiHandle.h"

@implementation CSMultiHandle

+(CSHandle *)handleWithHandleArray:(NSArray *)handlearray
{
	if(!handlearray) return nil;
	NSInteger count=[handlearray count];
	if(count==0) return nil;
	else if(count==1) return [handlearray objectAtIndex:0];
	else return [[[self alloc] initWithHandles:handlearray] autorelease];
}

+(CSHandle *)handleWithHandles:(CSHandle *)firsthandle,...
{
	if(!firsthandle) return nil;

	NSMutableArray *array=[NSMutableArray arrayWithObject:firsthandle];
	CSHandle *handle;
	va_list va;

	va_start(va,firsthandle);
	while((handle=va_arg(va,CSHandle *))) [array addObject:handle];
	va_end(va);

	return [self handleWithHandleArray:array];
}

-(id)initWithHandles:(NSArray *)handlearray
{
	if(self=[super init])
	{
		handles=[handlearray copy];
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
		while((handle=[enumerator nextObject])) [handlearray addObject:[[handle copy] autorelease]];

		handles=[[NSArray arrayWithArray:handlearray] retain];
	}
	return self;
}

-(void)dealloc
{
	[handles release];
	[super dealloc];
}

-(NSArray *)handles { return handles; }

-(NSInteger)numberOfSegments { return [handles count]; }

-(off_t)segmentSizeAtIndex:(NSInteger)index
{
	return [[handles objectAtIndex:index] fileSize];
}

-(CSHandle *)handleAtIndex:(NSInteger)index
{
	return [handles objectAtIndex:index];
}

@end
