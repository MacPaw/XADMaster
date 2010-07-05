#import "XADUnarchiver.h"
#import "NSStringPrinting.h"
#import "CSCommandLineParser.h"
#import "CommandLineCommon.h"

#define VERSION_STRING @"v0.1"

@interface Lister:NSObject
{
	int indent;
}
@end

@implementation Lister

-(id)initWithIndentLevel:(int)indentlevel
{
	if(self=[super init])
	{
		indent=indentlevel;
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
//	NSNumber *compsize=[dict objectForKey:XADCompressedSizeKey];
	NSNumber *size=[dict objectForKey:XADFileSizeKey];
	NSNumber *rsrc=[dict objectForKey:XADIsResourceForkKey];

	NSString *name=[[[dict objectForKey:XADFileNameKey] string] stringByEscapingControlCharacters];
	[name print];
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
	[@"\n" print];
}

@end




@interface JSONLister:NSObject
{
	int indent;
	BOOL asciimode;
}
@end

@implementation JSONLister

-(id)initWithASCIIEncoding:(BOOL)ascii
{
	if(self=[super init])
	{
		indent=0;
		asciimode=ascii;
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
//	for(int i=0;i<indent;i++) [@" " print];

}

@end



int main(int argc,const char **argv)
{
	NSAutoreleasePool *pool=[NSAutoreleasePool new];

	CSCommandLineParser *cmdline=[[CSCommandLineParser new] autorelease];

	[cmdline setUsageHeader:
	@"lsar " VERSION_STRING @" (" @__DATE__ @")\n"
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
	@"Do not attempt to extract archives contained in other archives. For instance, "
	@"when unpacking a .tar.gz file, only unpack the .tar file and not its contents."];
	[cmdline addAlias:@"nr" forOption:@"no-recursion"];

	[cmdline addSwitchOption:@"json" description:
	@"Print the listing in JSON format."];
	[cmdline addAlias:@"j" forOption:@"json"];

	[cmdline addSwitchOption:@"json-ascii" description:
	@"Print the listing in JSON format, encoded as pure ASCII text.."];
	[cmdline addAlias:@"ja" forOption:@"json-ascii"];

	[cmdline addHelpOption];

	//@"Usage: %@ archive [ archive2 ... ] [ destination_directory ]\n",
	if(![cmdline parseCommandLineWithArgc:argc argv:argv]) exit(1);

	NSString *encoding=[[cmdline stringValueForOption:@"encoding"] lowercaseString];
	if([encoding isEqual:@"list"]||[encoding isEqual:@"help"])
	{
		[@"Available encodings are:\n" print];
		PrintEncodingList();
		return 0;
	}

//	NSArray *files=[cmdline stringArrayValueForOption:@"files"];
	NSArray *files=[cmdline remainingArguments];
	int numfiles=[files count];

	if(numfiles==0)
	{
		[cmdline printUsage];
		return 1;
	}

	for(int i=0;i<numfiles;i++)
	{
		NSAutoreleasePool *pool=[[NSAutoreleasePool alloc] init];

		NSString *filename=[files objectAtIndex:i];

		[@"Listing " print];
		[filename print];
		[@"..." print];

		fflush(stdout);

		XADArchiveParser *parser=[XADArchiveParser archiveParserForPath:filename];

		if(parser)
		{
			[@"\n" print];

			if([cmdline boolValueForOption:@"json-ascii"])
			{
				[parser setDelegate:[[[JSONLister alloc] initWithASCIIEncoding:YES] autorelease]];
			}
			else if([cmdline boolValueForOption:@"json"])
			{
				[parser setDelegate:[[[JSONLister alloc] initWithASCIIEncoding:NO] autorelease]];
			}
			else
			{
				[parser setDelegate:[[[Lister alloc] initWithIndentLevel:2] autorelease]];
			}

			NSString *password=[cmdline stringValueForOption:@"password"];
			if(password) [parser setPassword:password];

			[parser parse];
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

