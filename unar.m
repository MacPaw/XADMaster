#import "XADSimpleUnarchiver.h"
#import "NSStringPrinting.h"
#import "CSCommandLineParser.h"
#import "CommandLineCommon.h"

#define VERSION_STRING @"v0.99"


int returncode;




@interface Unarchiver:NSObject
{
	int indent;
}
@end

@implementation Unarchiver

-(id)init
{
	if((self=[super init]))
	{
		indent=1;
	}
	return self;
}

-(void)printIndention
{
	for(int i=0;i<indent;i++) [@"  " print];
}

-(void)simpleUnarchiverNeedsPassword:(XADSimpleUnarchiver *)unarchiver
{
	[@"This archive requires a password to unpack. Use the -p option to provide one.\n" print];
	exit(2);
}


//-(NSString *)simpleUnarchiver:(XADSimpleUnarchiver *)unarchiver encodingNameForXADString:(XADString *)string;

-(NSString *)simpleUnarchiver:self replacementPathForEntryWithDictionary:(NSDictionary *)dict
originalPath:(NSString *)path suggestedPath:(NSString *)unique
{
	[@"Not implemented.\n" print];
	exit(1);
}

//-(BOOL)simpleUnarchiver:(XADSimpleUnarchiver *)unarchiver shouldExtractEntryWithDictionary:(NSDictionary *)dict to:(NSString *)path;

-(void)simpleUnarchiver:(XADSimpleUnarchiver *)unarchiver willExtractEntryWithDictionary:(NSDictionary *)dict to:(NSString *)path
{
	[self printIndention];

	NSNumber *dir=[dict objectForKey:XADIsDirectoryKey];
	NSNumber *link=[dict objectForKey:XADIsLinkKey];
//	NSNumber *compsize=[dict objectForKey:XADCompressedSizeKey];
	NSNumber *size=[dict objectForKey:XADFileSizeKey];
	NSNumber *rsrc=[dict objectForKey:XADIsResourceForkKey];

	NSString *name=[[[dict objectForKey:XADFileNameKey] string] stringByEscapingControlCharacters];
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

	[@")... " print];
	fflush(stdout);
}

-(void)simpleUnarchiver:(XADSimpleUnarchiver *)unarchiver didExtractEntryWithDictionary:(NSDictionary *)dict to:(NSString *)path error:(XADError)error
{
	if(!error) [@"OK.\n" print];
	else
	{
		[@"Failed! (" print];
		[[XADException describeXADError:error] print];
		[@")\n" print];

		returncode=1;
	}
}

-(BOOL)extractionShouldStopForSimpleUnarchiver:(XADSimpleUnarchiver *)unarchiver;
{
	return NO;
}

//-(void)simpleUnarchiver:(XADSimpleUnarchiver *)unarchiver
//extractionProgressForEntryWithDictionary:(NSDictionary *)dict
//fileProgress:(off_t)fileprogress of:(off_t)filesize
//totalProgress:(off_t)totalprogress of:(off_t)totalsize;
//-(void)simpleUnarchiver:(XADSimpleUnarchiver *)unarchiver
//estimatedExtractionProgressForEntryWithDictionary:(NSDictionary *)dict
//fileProgress:(double)fileprogress totalProgress:(double)totalprogress;

@end




int main(int argc,const char **argv)
{
	NSAutoreleasePool *pool=[NSAutoreleasePool new];

	CSCommandLineParser *cmdline=[[CSCommandLineParser new] autorelease];

	[cmdline setUsageHeader:
	@"unar " VERSION_STRING @" (" @__DATE__ @"), a tool for extracting the contents of archive files.\n"
	@"Usage: unar [options] archive [files...]\n"
	@"\n"
	@"Available options:\n"];

	[cmdline addStringOption:@"output-directory" description:
	@"The directory to write the contents of the archive to. "
	@"Defaults to the current directory."];
	[cmdline addAlias:@"o" forOption:@"output-directory"];

	[cmdline addSwitchOption:@"force-overwrite" description:
	@"Always overwrite files when a file to be unpacked already exists on disk."];
	[cmdline addAlias:@"f" forOption:@"force-overwrite"];

	[cmdline addSwitchOption:@"force-rename" description:
	@"Always rename files when a file to be unpacked already exists on disk."];
	[cmdline addAlias:@"r" forOption:@"force-rename"];

	[cmdline addSwitchOption:@"force-directory" description:
	@"Always create a containing directory for for the contents of the "
	@"unpacked archive. By default, a directory is created if there is more "
	@"than one top-level file or folder."];
	[cmdline addAlias:@"d" forOption:@"force-directory"];

	[cmdline addSwitchOption:@"no-directory" description:
	@"Never create a containing directory for for the contents of the "
	@"unpacked archive."];
	[cmdline addAlias:@"D" forOption:@"no-directory"];

	[cmdline addStringOption:@"password" description:
	@"The password to use for decrypting protected archives."];
	[cmdline addAlias:@"p" forOption:@"password"];

	[cmdline addStringOption:@"encoding" description:
	@"The encoding to use for filenames in the archive, when it is not known. "
	@"If not specified, the program attempts to auto-detect the encoding used. "
	@"Use \"help\" or \"list\" as the argument to give a listing of all supported encodings."
	argumentDescription:@"encoding name"];
	[cmdline addAlias:@"e" forOption:@"encoding"];

	[cmdline addStringOption:@"password-encoding" description:
	@"The encoding to use for the password for the archive, when it is not known. "
	@"If not specified, then either the encoding given by the -encoding option "
	@"or the auto-detected encoding is used."
	argumentDescription:@"name"];
	[cmdline addAlias:@"E" forOption:@"password-encoding"];

	[cmdline addSwitchOption:@"no-recursion" description:
	@"Do not attempt to extract archives contained in other archives. For instance, "
	@"when unpacking a .tar.gz file, only unpack the .tar file and not its contents."];
	[cmdline addAlias:@"nr" forOption:@"no-recursion"];

	[cmdline addSwitchOption:@"indexes" description:
	@"Instead of specifying the files to unpack as filenames or wildcard patterns, "
	@"specify them as indexes, as output by lsar."];
	[cmdline addAlias:@"i" forOption:@"indexes"];

	#ifdef __APPLE__

	[cmdline addMultipleChoiceOption:@"forks"
	allowedValues:[NSArray arrayWithObjects:@"fork",@"visible",@"hidden",@"skip",nil] defaultValue:@"fork"
	description:@"How to handle Mac OS resource forks. "
	@"\"fork\" creates regular resource forks, "
	@"\"visible\" creates AppleDouble files with the extension \".rsrc\", "
	@"\"hidden\" creates AppleDouble files with the prefix \"._\", "
	@"and \"skip\" discards all resource forks."];
 	[cmdline addAlias:@"k" forOption:@"forks"];

	int forkvalues[]={XADMacOSXForkStyle,XADVisibleAppleDoubleForkStyle,XADHiddenAppleDoubleForkStyle,XADIgnoredForkStyle};

	#else

	[cmdline addMultipleChoiceOption:@"forks"
	allowedValues:[NSArray arrayWithObjects:@"visible",@"hidden",@"skip",nil] defaultValue:@"visible"
	description:@"How to handle Mac OS resource forks. "
	@"\"visible\" creates AppleDouble files with the extension \".rsrc\", "
	@"\"hidden\" creates AppleDouble files with the prefix \"._\", "
	@"and \"skip\" discards all resource forks."];
 	[cmdline addAlias:@"k" forOption:@"forks"];

	int forkvalues[]={XADVisibleAppleDoubleForkStyle,XADHiddenAppleDoubleForkStyle,XADIgnoredForkStyle};

	#endif

	[cmdline addHelpOption];

	if(![cmdline parseCommandLineWithArgc:argc argv:argv]) exit(1);


	NSString *destination=[cmdline stringValueForOption:@"output-directory"];
	BOOL forceoverwrite=[cmdline boolValueForOption:@"force-overwrite"];
	BOOL forcerename=[cmdline boolValueForOption:@"force-rename"];
	BOOL forcedirectory=[cmdline boolValueForOption:@"force-directory"];
	BOOL nodirectory=[cmdline boolValueForOption:@"no-directory"];
	NSString *password=[cmdline stringValueForOption:@"password"];
	NSString *encoding=[cmdline stringValueForOption:@"encoding"];
	NSString *passwordencoding=[cmdline stringValueForOption:@"password-encoding"];
	BOOL norecursion=[cmdline boolValueForOption:@"no-recursion"];
	BOOL indexes=[cmdline boolValueForOption:@"indexes"];
	int forkstyle=forkvalues[[cmdline intValueForOption:@"forks"]];

	if(IsListRequest(encoding)||IsListRequest(passwordencoding))
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

	NSString *filename=[files objectAtIndex:0];

	[@"Extracting " print];
	[filename print];
	[@"..." print];

	fflush(stdout);

	XADError error;
	XADSimpleUnarchiver *unarchiver=[XADSimpleUnarchiver simpleUnarchiverForPath:filename error:&error];

	if(!unarchiver)
	{
		[@" Couldn't open archive. (" print];
		[[XADException describeXADError:error] print];
		[@")\n" print];
		return 1;
	}

	if(destination) [unarchiver setDestination:destination];
	if(password) [unarchiver setPassword:password];
	if(encoding) [[unarchiver archiveParser] setEncodingName:encoding];
	if(passwordencoding) [[unarchiver archiveParser] setPasswordEncodingName:passwordencoding];
	if(forcedirectory) [unarchiver setRemovesEnclosingDirectoryForSoloItems:NO];
	if(nodirectory) [unarchiver setEnclosingDirectoryName:nil];
	[unarchiver setAlwaysOverwritesFiles:forceoverwrite];
	[unarchiver setAlwaysRenamesFiles:forcerename];
	[unarchiver setExtractsSubArchives:!norecursion];
	[unarchiver setMacResourceForkStyle:forkstyle];

	for(int i=1;i<numfiles;i++)
	{
		NSString *filter=[files objectAtIndex:i];
		if(indexes) [unarchiver addIndexFilter:[filter intValue]];
		else [unarchiver addGlobFilter:filter];
	}

	[unarchiver setDelegate:[[[Unarchiver alloc] init] autorelease]];
			
	[@"\n" print];

	returncode=0;
	error=[unarchiver parseAndUnarchive];
	if(error)
	{
		[@"Failed! (" print];
		[[XADException describeXADError:error] print];
		[@")\n" print];
	}

	[pool release];

	return returncode;
}
