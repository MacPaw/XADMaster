#import "XADUnarchiver.h"
#import "NSStringPrinting.h"
#import "CSCommandLineParser.h"
#import "CSJSONPrinter.h"
#import "CommandLineCommon.h"

#define VERSION_STRING @"v0.1"



BOOL recurse,test;
NSString *password,*encoding;



#define EntryDoesNotNeedTestingResult 0
#define EntryIsNotSupportedResult 1
#define EntrySizeIsWrongResult 2
#define EntryHasNoChecksumResult 3
#define EntryChecksumIsIncorrectResult 4
#define EntryIsOkResult 5

static int TestEntry(XADArchiveParser *parser,NSDictionary *dict,CSHandle *handle)
{
	NSNumber *dir=[dict objectForKey:XADIsDirectoryKey];
	NSNumber *link=[dict objectForKey:XADIsLinkKey];
	NSNumber *archive=[dict objectForKey:XADIsArchiveKey];
	NSNumber *size=[dict objectForKey:XADFileSizeKey];

	BOOL isdir=dir&&[dir boolValue];
	BOOL islink=link&&[link boolValue];
	BOOL isarchive=archive&&[archive boolValue];

	if(isdir||islink) return EntryDoesNotNeedTestingResult;

	if(!handle) handle=[parser handleForEntryWithDictionary:dict wantChecksum:YES];

	if(!handle)
	{
		return EntryIsNotSupportedResult;
	}

	[handle seekToEndOfFile];

	if(![handle hasChecksum])
	{
		if(size&&[size longLongValue]!=[handle offsetInFile])
		{
			return EntrySizeIsWrongResult;
		}
		else
		{
			return EntryHasNoChecksumResult;
		}
	}
	else
	{
		if(![handle isChecksumCorrect])
		{
			return EntryChecksumIsIncorrectResult;
		}
		else if(size&&[size longLongValue]!=[handle offsetInFile])
		{
			return EntrySizeIsWrongResult; // Unlikely to happen
		}
		else
		{
			return EntryIsOkResult;
		}
	}
}




@interface Lister:NSObject
{
	int indent;
}
@end

@implementation Lister

-(id)init
{
	if(self=[super init])
	{
		indent=0;
	}
	return self;
}

-(void)archiveParserNeedsPassword:(XADArchiveParser *)parser
{
}

-(void)archiveParser:(XADArchiveParser *)parser foundEntryWithDictionary:(NSDictionary *)dict
{
	for(int i=0;i<indent;i++) [@" " print];

	NSNumber *dir=[dict objectForKey:XADIsDirectoryKey];
	NSNumber *link=[dict objectForKey:XADIsLinkKey];
	NSNumber *archive=[dict objectForKey:XADIsArchiveKey];
//	NSNumber *compsize=[dict objectForKey:XADCompressedSizeKey];
	NSNumber *size=[dict objectForKey:XADFileSizeKey];
	NSNumber *rsrc=[dict objectForKey:XADIsResourceForkKey];

	BOOL isdir=dir&&[dir boolValue];
	BOOL islink=link&&[link boolValue];
	BOOL isarchive=archive&&[archive boolValue];

	NSString *filename=[[dict objectForKey:XADFileNameKey] string];
	NSString *displayname=[filename stringByEscapingControlCharacters];
	[displayname print];

/*	[@" (" print];

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
	fflush(stdout);*/

	CSHandle *handle=nil;

	if(recurse&&isarchive)
	{
		//NSAutoreleasePool *pool=[NSAutoreleasePool new];

		handle=[parser handleForEntryWithDictionary:dict wantChecksum:YES];
		if(!handle) return;

		XADArchiveParser *subparser=[XADArchiveParser archiveParserForHandle:handle name:filename]; // TODO: provide a name?
		if(subparser)
		{
			if(password) [subparser setPassword:password];
			if(encoding) [[subparser stringSource] setFixedEncodingName:encoding];
			[subparser setDelegate:self];

			[@"\n" print];

			indent+=2;
			[subparser parse];
			indent-=2;
		}

		//[pool release];

		if(test) for(int i=0;i<indent;i++) [@" " print];
	}

	if(test)
	{
		switch(TestEntry(parser,dict,handle))
		{
			case EntryDoesNotNeedTestingResult: break;
			case EntryIsNotSupportedResult: [@" (Unsupported!)" print]; break;
			case EntrySizeIsWrongResult: [@" (Wrong size!)" print]; break;
			case EntryHasNoChecksumResult: [@" (Unknown)" print]; break;
			case EntryChecksumIsIncorrectResult: [@" (Checksum failed!)" print]; break;
			case EntryIsOkResult: [@" (Ok)" print]; break;
		}
	}

	[@"\n" print];
}

@end




@interface JSONLister:NSObject
{
	CSJSONPrinter *printer;
}
@end

@implementation JSONLister

-(id)initWithJSONPrinter:(CSJSONPrinter *)json
{
	if(self=[super init])
	{
		printer=[json retain];
	}
	return self;
}

-(void)archiveParserNeedsPassword:(XADArchiveParser *)parser
{
	// TODO: report useful error
	exit(1);
}

-(void)archiveParser:(XADArchiveParser *)parser foundEntryWithDictionary:(NSDictionary *)dict
{
	[printer printArrayObject:dict];
}

@end



int main(int argc,const char **argv)
{
	NSAutoreleasePool *pool=[NSAutoreleasePool new];

	CSCommandLineParser *cmdline=[[CSCommandLineParser new] autorelease];

	[cmdline setUsageHeader:
	@"lsar " VERSION_STRING @" (" @__DATE__ @"), a tool for listing the contents of archive files.\n"
	@"Usage: lsar [options] archive...\n"
	@"\n"
	@"Available options:\n"];

	[cmdline addStringOption:@"password" description:
	@"The password to use for decrypting protected archives."];
	[cmdline addAlias:@"p" forOption:@"password"];

	[cmdline addStringOption:@"encoding" description:
	@"The encoding to use for filenames in the archive, when it is not known. "
	@"Use \"help\" or \"list\" as the argument to give a listing of all supported encodings."];
	[cmdline addAlias:@"e" forOption:@"encoding"];

	[cmdline addSwitchOption:@"test" description:
	@"Test the integrity of the files in the archive, if possible."];
	[cmdline addAlias:@"t" forOption:@"test"];

	[cmdline addSwitchOption:@"no-recursion" description:
	@"Do not attempt to list the contents of archives contained in other archives. "
	@"For instance, when listing a .tar.gz file, only list the .tar file and not its contents."];
	[cmdline addAlias:@"nr" forOption:@"no-recursion"];

	[cmdline addSwitchOption:@"json" description:
	@"Print the listing in JSON format."];
	[cmdline addAlias:@"j" forOption:@"json"];

	[cmdline addSwitchOption:@"json-ascii" description:
	@"Print the listing in JSON format, encoded as pure ASCII text.."];
	[cmdline addAlias:@"ja" forOption:@"json-ascii"];

	[cmdline addHelpOption];

	if(![cmdline parseCommandLineWithArgc:argc argv:argv]) exit(1);

	NSString *encoding=[[cmdline stringValueForOption:@"encoding"] lowercaseString];
	if([encoding isEqual:@"list"]||[encoding isEqual:@"help"])
	{
		[@"Available encodings are:\n" print];
		PrintEncodingList();
		return 0;
	}

	NSArray *files=[cmdline remainingArguments];
	int numfiles=[files count];

	if(numfiles==0)
	{
		[cmdline printUsage];
		return 1;
	}

	password=[cmdline stringValueForOption:@"password"];
	encoding=[cmdline stringValueForOption:@"encoding"];
	test=[cmdline boolValueForOption:@"test"];
	recurse=![cmdline boolValueForOption:@"no-recursion"];

	BOOL json=[cmdline boolValueForOption:@"json"];
	BOOL jsonascii=[cmdline boolValueForOption:@"json-ascii"];

	if(json||jsonascii)
	{
		CSJSONPrinter *printer=[CSJSONPrinter new];
		[printer setIndentString:@"  "];
		[printer setASCIIMode:jsonascii];
		[printer startPrintingArray];

		for(int i=0;i<numfiles;i++)
		{
			NSAutoreleasePool *pool=[[NSAutoreleasePool alloc] init];
			NSString *filename=[files objectAtIndex:i];
			XADArchiveParser *parser=[XADArchiveParser archiveParserForPath:filename];

			if(parser)
			{
				if(password) [parser setPassword:password];
				if(encoding) [[parser stringSource] setFixedEncodingName:encoding];

				[printer startPrintingArrayObject];
				[printer startPrintingArray];
				[parser setDelegate:[[[JSONLister alloc] initWithJSONPrinter:printer] autorelease]];
				[parser parse];
				[printer endPrintingArray];
				[printer endPrintingArrayObject];
			}
			else
			{
				[printer printArrayObject:@"Couldn't open archive."];
			}

			[pool release];
		}

		[printer endPrintingArray];
		[@";\n" print];
	}
	else
	{
		for(int i=0;i<numfiles;i++)
		{
			NSAutoreleasePool *pool=[[NSAutoreleasePool alloc] init];
			NSString *filename=[files objectAtIndex:i];

			if(i!=0) [@"\n" print];
			[filename print];
			[@":" print];
			fflush(stdout);

			XADArchiveParser *parser=[XADArchiveParser archiveParserForPath:filename];

			if(parser)
			{
				[@"\n" print];

				if(password) [parser setPassword:password];
				if(encoding) [[parser stringSource] setFixedEncodingName:encoding];

				[parser setDelegate:[[[Lister alloc] init] autorelease]];
				[parser parse];
			}
			else
			{
				[@" Couldn't open archive.\n" print];
			}

			[pool release];
		}
	}

	[pool release];

	return 0;
}

