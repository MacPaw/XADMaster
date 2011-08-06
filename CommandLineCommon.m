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
	NSNumber *dirnum=[dict objectForKey:XADIsDirectoryKey];
	NSNumber *linknum=[dict objectForKey:XADIsLinkKey];
	NSNumber *resnum=[dict objectForKey:XADIsResourceForkKey];
	NSNumber *sizenum=[dict objectForKey:XADFileSizeKey];
//	NSNumber *compsize=[dict objectForKey:XADCompressedSizeKey];

	BOOL isdir=dirnum && [dirnum boolValue];
	BOOL islink=linknum && [linknum boolValue];
	BOOL isres=resnum && [resnum boolValue];
	BOOL hassize=(sizenum!=nil);

	NSString *name=[[dict objectForKey:XADFileNameKey] string];
	name=[name stringByEscapingControlCharacters];
	if(!isdir && !islink && !isres && !hassize) return name;

	NSMutableString *str=[NSMutableString stringWithString:name];

	if(isdir) [str appendString:@"/"];
	// TODO: What about Windows?

	[str appendString:@"  ("];

	if(isdir) [str appendString:@"dir"];
	else if(islink) [str appendString:@"link"];
	else if(hassize) [str appendFormat:@"%lld B",[sizenum longLongValue]];

	if(isres)
	{
		if(isdir||islink||hassize) [str appendString:@", "];
		[str appendString:@"rsrc"];
	}

	[str appendString:@")"];

	return str;
}




BOOL IsInteractive()
{
//	#ifdef __MINGW32__
//	return isatty(fileno(stdin))&&isatty(fileno(stdout));
//	#else
	return isatty(fileno(stdin))&&isatty(fileno(stdout));
//	#endif
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

	#ifdef __MINGW32__

	[@"Password (will be shown): " print];
	fflush(stdout);

	char pass[1024];
	fgets(pass,sizeof(pass),stdin);

	#else

	char *pass=getpass("Password (will not be shown): ");
	if(!pass) return nil;

	#endif

	return [NSString stringWithUTF8String:pass];
}
