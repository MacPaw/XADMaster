#import "CommandLineCommon.h"

#import "XADArchiveParser.h"
#import "XADString.h"
#import "NSStringPrinting.h"

#ifndef __MINGW32__
#import <unistd.h>
#endif

BOOL IsListRequest(NSString *encoding)
{
	if(!encoding) return NO;
	if([encoding caseInsensitiveCompare:@"list"]==NSOrderedSame) return YES;
	if([encoding caseInsensitiveCompare:@"help"]==NSOrderedSame) return YES;
	return NO;
}

void PrintEncodingList()
{
	NSEnumerator *enumerator=[[XADString availableEncodingNames] objectEnumerator];
	NSArray *encodingarray;
	while((encodingarray=[enumerator nextObject]))
	{
		NSString *description=[encodingarray objectAtIndex:0];
		if((id)description==[NSNull null]||[description length]==0) description=nil;

		NSString *encoding=[encodingarray objectAtIndex:1];

		NSString *aliases=nil;
		if([encodingarray count]>2) aliases=[[encodingarray subarrayWithRange:
		NSMakeRange(2,[encodingarray count]-2)] componentsJoinedByString:@", "];

		[@"  * " print];

		[encoding print];

		if(aliases)
		{
			[@" (" print];
			[aliases print];
			[@")" print];
		}

		if(description)
		{
			[@": " print];
			[description print];
		}

		[@"\n" print];
	}
}




NSString *DisplayNameForEntryWithDictionary(NSDictionary *dict)
{
	NSString *name=[[dict objectForKey:XADFileNameKey] string];
	name=[name stringByEscapingControlCharacters];

	NSNumber *dirnum=[dict objectForKey:XADIsDirectoryKey];
	if(dirnum && [dirnum boolValue]) name=[name stringByAppendingString:@"/"];
	// TODO: What about Windows?

	return name;
}




BOOL IsInteractive()
{
	#ifdef __MINGW32__
	return is_console(fileno(stdin))&&is_console(fileno(stdout));
	#else
	return isatty(fileno(stdin))&&isatty(fileno(stdout));
	#endif
}

int GetPromptCharacter()
{
	#ifdef __APPLE__
	fpurge(stdin);
	int c=getc(stdin);
	fpurge(stdin);
	#else
	// TODO: Handle purging.
	char c;
	if(scanf("%c%*c",&c)<1) return -1;
	#endif
	return c;
}

NSString *AskForPassword(NSString *prompt)
{
	[prompt print];
	fflush(stdout); // getpass() doesn't print its prompt to stdout.

	char *pass=getpass("Password (will not be shown): ");
	if(!pass) return nil;

	return [NSString stringWithUTF8String:pass];
}
