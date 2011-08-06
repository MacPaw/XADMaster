#import "XADSimpleUnarchiver.h"
#import "NSStringPrinting.h"
#import "CSCommandLineParser.h"
#import "CSJSONPrinter.h"
#import "CommandLineCommon.h"

#define VERSION_STRING @"v0.99"

#define EntryDoesNotNeedTestingResult 0
#define EntryIsNotSupportedResult 1
#define EntryFailsWhileUnpackingResult 2
#define EntrySizeIsWrongResult 3
#define EntryHasNoChecksumResult 4
#define EntryChecksumIsIncorrectResult 5
#define EntryIsOkResult 6

static int TestEntry(XADSimpleUnarchiver *unarchiver,NSDictionary *dict);


@interface Lister:NSObject {}
@end

@interface JSONLister:NSObject {}
@end

int returncode;
CSJSONPrinter *printer;
BOOL test,printindexes;
int passed,failed,unknown;

int main(int argc,const char **argv)
{
	NSAutoreleasePool *pool=[NSAutoreleasePool new];

	CSCommandLineParser *cmdline=[[CSCommandLineParser new] autorelease];

	[cmdline setUsageHeader:
	@"lsar " VERSION_STRING @" (" @__DATE__ @"), a tool for listing the contents of archive files.\n"
	@"Usage: lsar [options] archive [files ...]\n"
	@"\n"
	@"Available options:\n"];

	[cmdline addSwitchOption:@"test" description:
	@"Test the integrity of the files in the archive, if possible."];
	[cmdline addAlias:@"t" forOption:@"test"];

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

	[cmdline addSwitchOption:@"print-encoding" description:
	@"Print the auto-detected encoding and the confidence factor after the file list"];
	[cmdline addAlias:@"pe" forOption:@"print-encoding"];

	[cmdline addSwitchOption:@"print-indexes" description:
	@"Include the index numbers of the entries in the archive, for use with unar."];
	[cmdline addAlias:@"pi" forOption:@"print-indexes"];

	[cmdline addSwitchOption:@"indexes" description:
	@"Instead of specifying the files to list as filenames or wildcard patterns, "
	@"specify them as indexes."];
	[cmdline addAlias:@"i" forOption:@"indexes"];

	[cmdline addSwitchOption:@"json" description:
	@"Print the listing in JSON format."];
	[cmdline addAlias:@"j" forOption:@"json"];

	[cmdline addSwitchOption:@"json-ascii" description:
	@"Print the listing in JSON format, encoded as pure ASCII text."];
	[cmdline addAlias:@"ja" forOption:@"json-ascii"];

	[cmdline addSwitchOption:@"no-recursion" description:
	@"Do not attempt to list archives contained in other archives. For instance, "
	@"when unpacking a .tar.gz file, only list the .gz file and not its contents."];
	[cmdline addAlias:@"nr" forOption:@"no-recursion"];

	[cmdline addHelpOption];

	if(![cmdline parseCommandLineWithArgc:argc argv:argv]) exit(1);




	test=[cmdline boolValueForOption:@"test"];
	NSString *password=[cmdline stringValueForOption:@"password"];
	NSString *encoding=[cmdline stringValueForOption:@"encoding"];
	NSString *passwordencoding=[cmdline stringValueForOption:@"password-encoding"];
	BOOL printencoding=[cmdline boolValueForOption:@"print-encoding"];
	printindexes=[cmdline boolValueForOption:@"print-indexes"];
	BOOL indexes=[cmdline boolValueForOption:@"indexes"];
	BOOL json=[cmdline boolValueForOption:@"json"];
	BOOL jsonascii=[cmdline boolValueForOption:@"json-ascii"];
	BOOL norecursion=[cmdline boolValueForOption:@"no-recursion"];

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

	if(json)
	{
		printer=[CSJSONPrinter new];
		[printer setIndentString:@"  "];
		[printer setASCIIMode:jsonascii];

		[printer startPrintingDictionary];
		[printer printDictionaryKey:@"version"];
		[printer printDictionaryObject:[NSNumber numberWithInt:2]];

		XADError error;
		XADSimpleUnarchiver *unarchiver=[XADSimpleUnarchiver simpleUnarchiverForPath:filename error:&error];
		if(!unarchiver)
		{
			[printer printDictionaryKey:@"error"];
			[printer printDictionaryObject:[NSNumber numberWithInt:error]];
			[printer endPrintingDictionary];
			[@"\n" print];
			return 1;
		}

		if(password) [unarchiver setPassword:password];
		if(encoding) [[unarchiver archiveParser] setEncodingName:encoding];
		if(passwordencoding) [[unarchiver archiveParser] setPasswordEncodingName:passwordencoding];
		[unarchiver setExtractsSubArchives:!norecursion];
		[unarchiver setAlwaysOverwritesFiles:YES]; // Disable collision checks.

		for(int i=1;i<numfiles;i++)
		{
			NSString *filter=[files objectAtIndex:i];
			if(indexes) [unarchiver addIndexFilter:[filter intValue]];
			else [unarchiver addGlobFilter:filter];
		}

		[unarchiver setDelegate:[[JSONLister new] autorelease]];

		[printer printDictionaryKey:@"contents"];
		[printer startPrintingDictionaryObject];
		[printer startPrintingArray];

		returncode=0;

		error=[unarchiver parseAndUnarchive];

		[printer endPrintingArray];
		[printer endPrintingDictionaryObject];

		if(error)
		{
			[printer printDictionaryKey:@"error"];
			[printer printDictionaryObject:[NSNumber numberWithInt:error]];
			returncode=1;
		}

		XADArchiveParser *parser=[unarchiver archiveParser];
		[printer printDictionaryKey:@"encoding"];
		[printer printDictionaryObject:[parser encodingName]];
		[printer printDictionaryKey:@"confidence"];
		[printer printDictionaryObject:[NSNumber numberWithFloat:[parser encodingConfidence]]];

		[printer endPrintingDictionary];

		[@"\n" print];
	}
	else
	{
		[filename print];
		[@":" print];
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

		if(password) [unarchiver setPassword:password];
		if(encoding) [[unarchiver archiveParser] setEncodingName:encoding];
		if(passwordencoding) [[unarchiver archiveParser] setPasswordEncodingName:passwordencoding];
		[unarchiver setExtractsSubArchives:!norecursion];
		[unarchiver setAlwaysOverwritesFiles:YES]; // Disable collision checks.

		for(int i=1;i<numfiles;i++)
		{
			NSString *filter=[files objectAtIndex:i];
			if(indexes) [unarchiver addIndexFilter:[filter intValue]];
			else [unarchiver addGlobFilter:filter];
		}

		[unarchiver setDelegate:[[[Lister alloc] init] autorelease]];

		[@"\n" print];

		returncode=0;
		passed=failed=unknown=0;

		error=[unarchiver parseAndUnarchive];
		if(error)
		{
			[@"Listing failed! (" print];
			[[XADException describeXADError:error] print];
			[@")\n" print];
		}

		if(test)
		{
			if(unknown)
			{
				[[NSString stringWithFormat:@"%d passed, %d failed, %d unknown.\n",
				passed,failed,unknown] print];
			}
			else
			{
				[[NSString stringWithFormat:@"%d passed, %d failed.\n",
				passed,failed] print];
			}
		}

		if(printencoding)
		{
			XADArchiveParser *parser=[unarchiver archiveParser];
			[[NSString stringWithFormat:@"Encoding: %@ (%d%% confidence)\n",
			[parser encodingName],(int)([parser encodingConfidence]*100+0.5)] print];
		}
	}

	[pool release];

	return returncode;
}



@implementation Lister

-(void)simpleUnarchiverNeedsPassword:(XADSimpleUnarchiver *)unarchiver
{
	// Ask for a password from the user if called in interactive mode,
	// otherwise just print an error on stderr and exit.
 	if(IsInteractive())
	{
		NSString *password=AskForPassword(@"This archive requires a password to list.\n");
		if(!password) exit(2);
		[unarchiver setPassword:password];
	}
	else
	{
		[@"This archive requires a password to unpack. Use the -p option to provide one.\n" printToFile:stderr];
		exit(2);
	}
}

-(BOOL)simpleUnarchiver:(XADSimpleUnarchiver *)unarchiver shouldExtractEntryWithDictionary:(NSDictionary *)dict to:(NSString *)path
{
	[@"  " print];

	if(printindexes)
	{
		NSNumber *indexnum=[dict objectForKey:XADIndexKey];
		[[indexnum description] print];
		[@". " print];
	}

	NSString *name=DisplayNameForEntryWithDictionary(dict);
	[name print];

	if(test)
	{
		[@"... " print];
		fflush(stdout);

		switch(TestEntry(unarchiver,dict))
		{
			case EntryDoesNotNeedTestingResult: passed++; break;
			case EntryIsNotSupportedResult: [@"Unsupported!" print]; failed++; break;
			case EntryFailsWhileUnpackingResult: [@"Unpacking failed!" print]; failed++; break;
			case EntrySizeIsWrongResult: [@"Wrong size!" print]; failed++; break;
			case EntryHasNoChecksumResult: [@"Unknown." print]; unknown++; break;
			case EntryChecksumIsIncorrectResult: [@"Checksum failed!" print]; failed++; break;
			case EntryIsOkResult: [@"OK." print]; passed++; break;
		}
	}

	[@"\n" print];

	return NO;
}

@end

@implementation JSONLister

-(void)simpleUnarchiverNeedsPassword:(XADSimpleUnarchiver *)unarchiver
{
	// Just print an error to stderr and return 2 to indicate a password is needed.
	// TODO: This breaks the JSON output, should this be fixed?
	[@"This archive requires a password to unpack. Use the -p option to provide one.\n" printToFile:stderr];
	exit(2);
}

-(BOOL)simpleUnarchiver:(XADSimpleUnarchiver *)unarchiver shouldExtractEntryWithDictionary:(NSDictionary *)dict to:(NSString *)path
{
	[printer startPrintingArrayObject];
	[printer startPrintingDictionary];

	[printer printDictionaryKeysAndObjects:dict];

	if(test)
	{
		[printer printDictionaryKey:@"lsarTestResult"];
		switch(TestEntry(unarchiver,dict))
		{
			case EntryDoesNotNeedTestingResult: [printer printDictionaryObject:@"not_tested"]; break;
			case EntryIsNotSupportedResult: [printer printDictionaryObject:@"not_supported"]; break;
			case EntryFailsWhileUnpackingResult: [printer printDictionaryObject:@"unpacking_failed"]; break;
			case EntrySizeIsWrongResult: [printer printDictionaryObject:@"wrong_size"]; break;
			case EntryHasNoChecksumResult: [printer printDictionaryObject:@"no_checksum"]; break;
			case EntryChecksumIsIncorrectResult: [printer printDictionaryObject:@"wrong_checksum"]; break;
			case EntryIsOkResult: [printer printDictionaryObject:@"ok"]; break;
		}
	}

	[printer endPrintingDictionary];
	[printer endPrintingArrayObject];

	return NO;
}

@end

static int TestEntry(XADSimpleUnarchiver *unarchiver,NSDictionary *dict)
{
	NSNumber *dir=[dict objectForKey:XADIsDirectoryKey];
	NSNumber *link=[dict objectForKey:XADIsLinkKey];
	NSNumber *size=[dict objectForKey:XADFileSizeKey];

	BOOL isdir=dir&&[dir boolValue];
	BOOL islink=link&&[link boolValue];

	if(isdir||islink) return EntryDoesNotNeedTestingResult;

	XADArchiveParser *parser=[unarchiver archiveParser];
	CSHandle *handle=[parser handleForEntryWithDictionary:dict wantChecksum:YES error:NULL];

	if(!handle)
	{
		returncode=1;
		return EntryIsNotSupportedResult;
	}

	@try
	{
		[handle seekToEndOfFile];
	}
	@catch(id exception)
	{
		returncode=1;
		return EntryFailsWhileUnpackingResult;
	}

	if(![handle hasChecksum])
	{
		if(size&&[size longLongValue]!=[handle offsetInFile])
		{
			returncode=1;
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
			returncode=1;
			return EntryChecksumIsIncorrectResult;
		}
		else if(size&&[size longLongValue]!=[handle offsetInFile])
		{
			returncode=1;
			return EntrySizeIsWrongResult; // Unlikely to happen
		}
		else
		{
			return EntryIsOkResult;
		}
	}
}

