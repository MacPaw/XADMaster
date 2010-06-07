#import "XADUnarchiver.h"
#import "NSStringXAD.h"

#ifdef __MINGW32__
#import <windows.h>
#endif

#define VERSION_STRING @"v0.2"

NSString *EscapeString(NSString *str)
{
	NSMutableString *res=[NSMutableString string];
	int length=[str length];
	for(int i=0;i<length;i++)
	{
		unichar c=[str characterAtIndex:i];
		if(c<32) [res appendFormat:@"^%c",c+64];
		else [res appendFormat:@"%C",c];
	}
	return res;
}

@interface Unarchiver:NSObject
{
	int indent;
}
@end

@implementation Unarchiver

-(id)initWithIndentLevel:(int)indentlevel
{
	if(self=[super init])
	{
		indent=indentlevel;
	}
	return self;
}

-(void)unarchiverNeedsPassword:(XADUnarchiver *)unarchiver
{
}

-(NSString *)unarchiver:(XADUnarchiver *)unarchiver pathForExtractingEntryWithDictionary:(NSDictionary *)dict
{
	return nil;
}

-(BOOL)unarchiver:(XADUnarchiver *)unarchiver shouldExtractEntryWithDictionary:(NSDictionary *)dict to:(NSString *)path
{
	return YES;
}

-(void)unarchiver:(XADUnarchiver *)unarchiver willExtractEntryWithDictionary:(NSDictionary *)dict to:(NSString *)path
{
	for(int i=0;i<indent;i++) [@" " print];

	NSNumber *dir=[dict objectForKey:XADIsDirectoryKey];
	NSNumber *link=[dict objectForKey:XADIsLinkKey];
//	NSNumber *compsize=[dict objectForKey:XADCompressedSizeKey];
	NSNumber *size=[dict objectForKey:XADFileSizeKey];
	NSNumber *rsrc=[dict objectForKey:XADIsResourceForkKey];

	NSString *name=EscapeString([[dict objectForKey:XADFileNameKey] string]);
	[name print];
	[@" (" print];

	if(dir&&[dir boolValue])
	{
		[@"dir" print];
	}
	else if(link&&[link boolValue]) [@"link" print];
	else
	{
		if(size) [[NSString stringWithFormat:@"%lld",[size longLongValue]] print];
		else [@"?" print];
	}

	if(rsrc&&[rsrc boolValue]) [@", rsrc" print];

	[@")..." print];
	fflush(stdout);
}

-(void)unarchiver:(XADUnarchiver *)unarchiver finishedExtractingEntryWithDictionary:(NSDictionary *)dict to:(NSString *)path
{
}

-(void)unarchiver:(XADUnarchiver *)unarchiver didExtractEntryWithDictionary:(NSDictionary *)dict to:(NSString *)path error:(XADError)error
{
	if(!error) [@" OK.\n" print];
	else
	{
		[@" Failed! (" print];
		[[XADException describeXADError:error] print];
		[@")\n" print];
	}
}

-(BOOL)unarchiver:(XADUnarchiver *)unarchiver shouldCreateDirectory:(NSString *)directory
{
	return YES;
}

-(BOOL)unarchiver:(XADUnarchiver *)unarchiver shouldExtractArchiveEntryWithDictionary:(NSDictionary *)dict to:(NSString *)path
{
	return YES;
}

-(void)unarchiver:(XADUnarchiver *)unarchiver willExtractArchiveEntryWithDictionary:(NSDictionary *)dict withUnarchiver:(XADUnarchiver *)subunarchiver to:(NSString *)path
{
	indent+=2;
}

-(void)unarchiver:(XADUnarchiver *)unarchiver didExtractArchiveEntryWithDictionary:(NSDictionary *)dict withUnarchiver:(XADUnarchiver *)subunarchiver to:(NSString *)path error:(XADError)error
{
	indent-=2;
}

-(NSString *)unarchiver:(XADUnarchiver *)unarchiver linkDestinationForEntryWithDictionary:(NSDictionary *)dict from:(NSString *)path
{
	return nil;
}

-(BOOL)extractionShouldStopForUnarchiver:(XADUnarchiver *)unarchiver
{
	return NO;
}

-(void)unarchiver:(XADUnarchiver *)unarchiver extractionProgressForEntryWithDictionary:(NSDictionary *)dict
fileFraction:(double)fileprogress estimatedTotalFraction:(double)totalprogress
{
}

@end



NSArray *CommandLineArguments(int argc,const char **argv)
{
	NSMutableArray *arguments=[NSMutableArray array];

	#ifdef __MINGW32__

	int wargc;
	wchar_t **wargv=CommandLineToArgvW(GetCommandLineW(),&wargc);

	for(int i=0;i<wargc;i++) [arguments addObject:
	[NSString stringWithCharacters:wargv[i] length:wcslen(wargv[i])]];

	#else

	for(int i=0;i<argc;i++) [arguments addObject:[NSString stringWithUTF8String:argv[i]]];

	#endif

	return arguments;
}

void PrintUsage(NSString *name)
{
	[[NSString stringWithFormat:
	@"unar " VERSION_STRING @" (" @__DATE__ @")\n"
	@"Usage: %@ archive [ archive2 ... ] [ destination_directory ]\n",
	name] printToFile:stderr];
}

int main(int argc,const char **argv)
{
	NSAutoreleasePool *pool=[NSAutoreleasePool new];

	NSArray *arguments=CommandLineArguments(argc,argv);
	int numfiles=[arguments count]-1;

	if(numfiles==0)
	{
		PrintUsage([arguments objectAtIndex:0]);
		return 0;
	}

	NSString *destination=nil;

	if(numfiles>1)
	{
		NSString *path=[arguments lastObject];
		BOOL isdir;
		if(![[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isdir]||isdir)
		{
			destination=path;
			numfiles--;
		}
	}

	for(int i=0;i<numfiles;i++)
	{
		NSAutoreleasePool *pool=[[NSAutoreleasePool alloc] init];

		NSString *filename=[arguments objectAtIndex:i+1];

		[@"Extracting " print];
		[filename print];
		[@"..." print];

		fflush(stdout);

		XADUnarchiver *unarchiver=[XADUnarchiver unarchiverForPath:filename];

		if(unarchiver)
		{
			[@"\n" print];
//[unarchiver setMacResourceForkStyle:XADVisibleAppleDoubleForkStyle];
			if(destination) [unarchiver setDestination:destination];

			[unarchiver setDelegate:[[[Unarchiver alloc] initWithIndentLevel:2] autorelease]];

			//char *pass=getenv("XADTestPassword");
			//if(pass) [parser setPassword:[NSString stringWithUTF8String:pass]];

			[unarchiver parseAndUnarchive];
		}
		else
		{
			[@" Couldn't open archive.\n" print];
		}

		[pool release];
	}

	[pool release];

	return 0;
}
