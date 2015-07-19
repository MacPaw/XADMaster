#import "XADSimpleUnarchiver.h"
#import "NSStringPrinting.h"
#import "CSCommandLineParser.h"
#import "CommandLineCommon.h"

#define VERSION_STRING @"v1.8.1"

@interface Unarchiver:NSObject {}
@end

int numerrors;
BOOL isinteractive;
FILE *outstream,*errstream;

int main(int argc,const char **argv)
{
	#ifdef GNUSTEP
	setlocale(LC_ALL,""); // GNUstep requires this.
	#endif

	NSAutoreleasePool *pool=[NSAutoreleasePool new];

	CSCommandLineParser *cmdline=[[CSCommandLineParser new] autorelease];

	[cmdline setUsageHeader:
	@"unar " VERSION_STRING @" (" @__DATE__ @"), a tool for extracting the contents of archive files.\n"
	@"Usage: unar [options] archive [files ...]\n"
	@"\n"
	@"Available options:\n"];

	[cmdline setProgramVersion:VERSION_STRING];

	[cmdline addStringOption:@"output-directory" description:
	@"The directory to write the contents of the archive to. "
	@"Defaults to the current directory."];
	[cmdline addAlias:@"o" forOption:@"output-directory"];

	[cmdline addSwitchOption:@"force-overwrite" description:
	@"Always overwrite files when a file to be unpacked already exists on disk. "
	@"By default, the program asks the user if possible, otherwise skips the file."];
	[cmdline addAlias:@"f" forOption:@"force-overwrite"];

	[cmdline addSwitchOption:@"force-rename" description:
	@"Always rename files when a file to be unpacked already exists on disk."];
	[cmdline addAlias:@"r" forOption:@"force-rename"];

	[cmdline addSwitchOption:@"force-skip" description:
	@"Always skip files when a file to be unpacked already exists on disk."];
	[cmdline addAlias:@"s" forOption:@"force-skip"];

	[cmdline addSwitchOption:@"force-directory" description:
	@"Always create a containing directory for the contents of the "
	@"unpacked archive. By default, a directory is created if there is more "
	@"than one top-level file or folder."];
	[cmdline addAlias:@"d" forOption:@"force-directory"];

	[cmdline addSwitchOption:@"no-directory" description:
	@"Never create a containing directory for the contents of the "
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

	[cmdline addSwitchOption:@"indexes" description:
	@"Instead of specifying the files to unpack as filenames or wildcard patterns, "
	@"specify them as indexes, as output by lsar."];
	[cmdline addAlias:@"i" forOption:@"indexes"];

	[cmdline addSwitchOption:@"no-recursion" description:
	@"Do not attempt to extract archives contained in other archives. For instance, "
	@"when unpacking a .tar.gz file, only unpack the .gz file and not its contents."];
	[cmdline addAlias:@"nr" forOption:@"no-recursion"];

	[cmdline addSwitchOption:@"copy-time" description:
	@"Copy the file modification time from the archive file to the containing directory, "
	@"if one is created."];
	[cmdline addAlias:@"t" forOption:@"copy-time"];

	#if defined(__APPLE__)

	[cmdline addSwitchOption:@"no-quarantine" description:
	@"Do not copy Finder quarantine metadata from the archive to the extracted files."];
	[cmdline addAlias:@"nq" forOption:@"no-quarantine"];

	[cmdline addMultipleChoiceOption:@"forks"
	allowedValues:[NSArray arrayWithObjects:@"fork",@"visible",@"hidden",@"skip",nil] defaultValue:@"fork"
	description:@"How to handle Mac OS resource forks. "
	@"\"fork\" creates regular resource forks, "
	@"\"visible\" creates AppleDouble files with the extension \".rsrc\", "
	@"\"hidden\" creates AppleDouble files with the prefix \"._\", "
	@"and \"skip\" discards all resource forks. Defaults to \"fork\"."];
 	[cmdline addAlias:@"k" forOption:@"forks"];

	int forkvalues[]={XADMacOSXForkStyle,XADVisibleAppleDoubleForkStyle,XADHiddenAppleDoubleForkStyle,XADIgnoredForkStyle};

	#elif defined(_WIN32)

	[cmdline addMultipleChoiceOption:@"forks"
	allowedValues:[NSArray arrayWithObjects:@"visible",@"hidden",@"hfv",@"skip",nil] defaultValue:@"visible"
	description:@"How to handle Mac OS resource forks. "
	@"\"visible\" creates AppleDouble files with the extension \".rsrc\", "
	@"\"hidden\" creates AppleDouble files with the prefix \"._\", "
	@"\"hfv\" creates AppleDouble files with the prefix \"%\", "
	@"and \"skip\" discards all resource forks. Defaults to \"visible\"."];
 	[cmdline addAlias:@"k" forOption:@"forks"];

	int forkvalues[]={XADVisibleAppleDoubleForkStyle,XADHiddenAppleDoubleForkStyle,XADHFVExplorerAppleDoubleForkStyle,XADIgnoredForkStyle};

	#else

	[cmdline addMultipleChoiceOption:@"forks"
	allowedValues:[NSArray arrayWithObjects:@"visible",@"hidden",@"skip",nil] defaultValue:@"visible"
	description:@"How to handle Mac OS resource forks. "
	@"\"visible\" creates AppleDouble files with the extension \".rsrc\", "
	@"\"hidden\" creates AppleDouble files with the prefix \"._\", "
	@"and \"skip\" discards all resource forks. Defaults to \"visible\"."];
 	[cmdline addAlias:@"k" forOption:@"forks"];

	int forkvalues[]={XADVisibleAppleDoubleForkStyle,XADHiddenAppleDoubleForkStyle,XADIgnoredForkStyle};

	#endif

	[cmdline addSwitchOption:@"quiet" description:@"Run in quiet mode."];
	[cmdline addAlias:@"q" forOption:@"quiet"];

	[cmdline addVersionOption];

	[cmdline addHelpOption];

	if(![cmdline parseCommandLineWithArgc:argc argv:argv]) exit(1);



	NSString *destination=[cmdline stringValueForOption:@"output-directory"];
	BOOL forceoverwrite=[cmdline boolValueForOption:@"force-overwrite"];
	BOOL forcerename=[cmdline boolValueForOption:@"force-rename"];
	BOOL forceskip=[cmdline boolValueForOption:@"force-skip"];
	BOOL forcedirectory=[cmdline boolValueForOption:@"force-directory"];
	BOOL nodirectory=[cmdline boolValueForOption:@"no-directory"];
	NSString *password=[cmdline stringValueForOption:@"password"];
	NSString *encoding=[cmdline stringValueForOption:@"encoding"];
	NSString *passwordencoding=[cmdline stringValueForOption:@"password-encoding"];
	BOOL indexes=[cmdline boolValueForOption:@"indexes"];
	BOOL norecursion=[cmdline boolValueForOption:@"no-recursion"];
	BOOL copytime=[cmdline boolValueForOption:@"copy-time"];
	BOOL noquarantine=[cmdline boolValueForOption:@"no-quarantine"];
	int forkstyle=forkvalues[[cmdline intValueForOption:@"forks"]];
	BOOL quietmode=[cmdline boolValueForOption:@"quiet"];

	if(quietmode)
	{
		isinteractive=NO;
		outstream=NULL;
		errstream=stderr;
	}
	else
	{
		isinteractive=IsInteractive();
		outstream=errstream=stdout;
	}

	if(IsListRequest(encoding)||IsListRequest(passwordencoding))
	{
		[@"Available encodings are:\n" printToFile:outstream];
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

	[filename printToFile:outstream];
	[@": " printToFile:outstream];
	if(outstream) fflush(outstream);

	XADError openerror;
	XADSimpleUnarchiver *unarchiver=[XADSimpleUnarchiver simpleUnarchiverForPath:filename error:&openerror];
	if(!unarchiver)
	{
		if(openerror)
		{
			[@"Couldn't open archive. (" printToFile:errstream];
			[[XADException describeXADError:openerror] printToFile:errstream];
			[@".)\n" printToFile:errstream];
		}
		else
		{
			[@"Couldn't recognize the archive format.\n" printToFile:errstream];
		}
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
	[unarchiver setAlwaysSkipsFiles:forceskip];
	[unarchiver setExtractsSubArchives:!norecursion];
	[unarchiver setPropagatesRelevantMetadata:!noquarantine];
	[unarchiver setCopiesArchiveModificationTimeToEnclosingDirectory:copytime];
	[unarchiver setMacResourceForkStyle:forkstyle];

	for(int i=1;i<numfiles;i++)
	{
		NSString *filter=[files objectAtIndex:i];
		if(indexes) [unarchiver addIndexFilter:[filter intValue]];
		else [unarchiver addGlobFilter:filter];
	}

	[unarchiver setDelegate:[[Unarchiver new] autorelease]];

	XADError parseerror=[unarchiver parse];

	if([unarchiver innerArchiveParser])
	{
		[[[unarchiver innerArchiveParser] formatName] printToFile:outstream];
		[@" in " printToFile:outstream];
		[[[unarchiver outerArchiveParser] formatName] printToFile:outstream];
	}
	else
	{
		[[[unarchiver outerArchiveParser] formatName] printToFile:outstream];
	}

	[@"\n" printToFile:outstream];

	numerrors=0;

	XADError unarchiveerror=[unarchiver unarchive];

	if(parseerror)
	{
		[@"Archive parsing failed! (" printToFile:errstream];
		[[XADException describeXADError:parseerror] printToFile:errstream];
		[@".)\n" printToFile:errstream];
	}

	if(unarchiveerror||numerrors)
	{
		NSString *destination=[unarchiver actualDestination];
		if(!destination) destination=[unarchiver destination];

		if(!destination||[destination isEqual:@"."])
		{
			[@"Extraction to current directory failed! (" printToFile:errstream];
		}
		else
		{
			[@"Extraction to directory \"" printToFile:errstream];
			[destination printToFile:errstream];
			[@"\" failed (" printToFile:errstream];
		}

		if(unarchiveerror) [[XADException describeXADError:unarchiveerror] printToFile:errstream];
		else [[NSString stringWithFormat:@"%d file%s failed",
		numerrors,numerrors==1?"":"s"] printToFile:errstream];

		[@".)\n" printToFile:errstream];
	}
	else if([unarchiver numberOfItemsExtracted])
	{
		NSString *result=[unarchiver createdItemOrActualDestination];

		if([result isEqual:@"."])
		{
			[@"Successfully extracted to current directory.\n" printToFile:outstream];
		}
		else
		{
			[@"Successfully extracted to \"" printToFile:outstream];
			[result printToFile:outstream];
			[@"\".\n" printToFile:outstream];
		}
	}
	else
	{
		[@"No files extracted.\n" printToFile:outstream];
	}

	// TODO: Print interest?

	[pool release];

	return parseerror||unarchiveerror||numerrors;
}

@implementation Unarchiver

-(void)simpleUnarchiverNeedsPassword:(XADSimpleUnarchiver *)unarchiver
{
	// Ask for a password from the user if called in interactive mode,
	// otherwise just print an error and exit.
 	if(isinteractive)
	{
		NSString *password=AskForPassword(@"This archive requires a password to unpack.\n");
		if(!password) exit(2);
		[unarchiver setPassword:password];
	}
	else
	{
		[@"This archive requires a password to unpack. Use the -p option to provide one.\n" printToFile:errstream];
		exit(2);
	}
}


//-(NSString *)simpleUnarchiver:(XADSimpleUnarchiver *)unarchiver encodingNameForXADString:(id <XADString>)string;

-(NSString *)simpleUnarchiver:(XADSimpleUnarchiver *)unarchiver replacementPathForEntryWithDictionary:(NSDictionary *)dict
originalPath:(NSString *)path suggestedPath:(NSString *)unique
{
	// Skip files and report as error if not interactive.
 	if(!isinteractive)
	{
		[@"  " printToFile:errstream];
		NSString *name=MediumInfoLineForEntryWithDictionary(dict);
		[name printToFile:errstream];
		[@"... Skipping existing file.\n" printToFile:errstream];
		numerrors++;
		return nil;
	}

	[@"\"" printToFile:outstream];
	[[path stringByEscapingControlCharacters] printToFile:outstream];
	[@"\" already exists.\n" printToFile:outstream];

	for(;;)
	{
		[@"(r)ename to \"" printToFile:outstream];
		[[[unique lastPathComponent] stringByEscapingControlCharacters] printToFile:outstream];
		[@"\", (R)ename all, (o)verwrite, (O)verwrite all, (s)kip, (S)kip all, (q)uit? " printToFile:outstream];
		if(outstream) fflush(outstream);

		switch(GetPromptCharacter())
		{
			case 'r': return unique;
			case 'R': [unarchiver setAlwaysRenamesFiles:YES]; return unique;
			case 'o': return path;
			case 'O': [unarchiver setAlwaysOverwritesFiles:YES]; return path;
			case 's': return nil;
			case 'S': [unarchiver setAlwaysSkipsFiles:YES]; return nil;
			case 'q': exit(1);
		}
	}
}

-(NSString *)simpleUnarchiver:(XADSimpleUnarchiver *)unarchiver deferredReplacementPathForOriginalPath:(NSString *)path
suggestedPath:(NSString *)unique
{
	return [self simpleUnarchiver:unarchiver replacementPathForEntryWithDictionary:nil
	originalPath:path suggestedPath:unique];
}

-(void)simpleUnarchiver:(XADSimpleUnarchiver *)unarchiver willExtractEntryWithDictionary:(NSDictionary *)dict to:(NSString *)path
{
	[@"  " printToFile:outstream];

	NSString *name=MediumInfoLineForEntryWithDictionary(dict);
	[name printToFile:outstream];

	[@"... " printToFile:outstream];
	if(outstream) fflush(outstream);
}

-(void)simpleUnarchiver:(XADSimpleUnarchiver *)unarchiver didExtractEntryWithDictionary:(NSDictionary *)dict to:(NSString *)path error:(XADError)error
{
	if(!error)
	{
		[@"OK.\n" printToFile:outstream];
	}
	else
	{
		if(errstream==stderr)
		{
			[@"  " printToFile:errstream];
			NSString *name=MediumInfoLineForEntryWithDictionary(dict);
			[name printToFile:errstream];
			[@"... " printToFile:errstream];
		}
		[@"Failed! (" printToFile:errstream];
		[[XADException describeXADError:error] printToFile:errstream];
		[@")\n" printToFile:errstream];

		numerrors++;
	}
}

-(BOOL)extractionShouldStopForSimpleUnarchiver:(XADSimpleUnarchiver *)unarchiver;
{
	return NO;
}

@end
