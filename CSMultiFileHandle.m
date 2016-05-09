#import "CSMultiFileHandle.h"
#import "CSFileHandle.h"

#include <sys/stat.h>

@implementation CSMultiFileHandle

+(CSHandle *)handleWithPathArray:(NSArray *)patharray
{
	if(!patharray) return nil;
	NSInteger count=[patharray count];
	if(count==0) return nil;
	else if(count==1) return [CSFileHandle fileHandleForReadingAtPath:[patharray objectAtIndex:0]];
	else return [[[self alloc] initWithPaths:patharray] autorelease];
}

+(CSHandle *)handleWithPaths:(CSHandle *)firstpath,...
{
	if(!firstpath) return nil;

	NSMutableArray *array=[NSMutableArray arrayWithObject:firstpath];
	NSString *path;
	va_list va;

	va_start(va,firstpath);
	while((path=va_arg(va,NSString *))) [array addObject:path];
	va_end(va);

	return [self handleWithPathArray:array];
}

-(id)initWithPaths:(NSArray *)patharray
{
	if(self=[super init])
	{
		paths=[patharray copy];
	}
	return self;
}

-(id)initAsCopyOf:(CSMultiFileHandle *)other
{
	if(self=[super initAsCopyOf:other])
	{
		paths=[other->paths retain];
	}
	return self;
}

-(void)dealloc
{
	[paths release];
	[super dealloc];
}

-(NSArray *)paths { return paths; }

-(NSInteger)numberOfSegments { return [paths count]; }

-(off_t)segmentSizeAtIndex:(NSInteger)index
{
	NSString *path=[paths objectAtIndex:index];

	#if defined(__COCOTRON__) // Cocotron
	struct _stati64 s;
	if(_wstati64([path fileSystemRepresentationW],&s)) [self _raiseError];
	#elif defined(__MINGW32__) // GNUstep under mingw32 - sort of untested
	struct _stati64 s;
	if(_wstati64((const wchar_t *)[path fileSystemRepresentation],&s)) [self _raiseError];
	#else // Cocoa or GNUstep under Linux
	struct stat s;
	if(stat([path fileSystemRepresentation],&s)) [self _raiseError];
	#endif

	return s.st_size;
}

-(CSHandle *)handleAtIndex:(NSInteger)index
{
	NSString *path=[paths objectAtIndex:index];
	return [CSFileHandle fileHandleForReadingAtPath:path];
}

-(void)_raiseError
{
	[[[[NSException alloc] initWithName:CSFileErrorException
	reason:[NSString stringWithFormat:@"Error while attempting to read file \"%@\": %s.",[self name],strerror(errno)]
	userInfo:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:errno] forKey:@"ErrNo"]] autorelease] raise];
}

@end
