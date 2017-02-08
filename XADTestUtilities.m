#import "XADTestUtilities.h"
#import "XADRegex.h"

NSString *FigureOutPassword(NSString *filename)
{
	const char *envpass=getenv("XADTestPassword");
	if(envpass) return [NSString stringWithUTF8String:envpass];

	NSArray *matches=[filename substringsCapturedByPattern:@"_pass_(.+)\\.[pP][aA][rR][tT][0-9]+\\.[rR][aA][rR]$"];
	if(matches) return [matches objectAtIndex:1];

	matches=[filename substringsCapturedByPattern:@"_pass_(.+)\\.[^.]+$"];
	if(matches) return [matches objectAtIndex:1];

	return nil;
}

NSArray *FilesForArgs(int argc,char **argv)
{
	NSMutableArray *files=[NSMutableArray array];

	for(int i=1;i<argc;i++)
	{
		NSAutoreleasePool *pool=[[NSAutoreleasePool alloc] init];

		NSString *filename=[NSString stringWithUTF8String:argv[i]];
		NSURL *url=[NSURL fileURLWithPath:filename];

		NSNumber *isdir;
		[url getResourceValue:&isdir forKey:NSURLIsDirectoryKey error:NULL];
		if(isdir.boolValue)
		{
			NSDirectoryEnumerator *enumerator=[[NSFileManager defaultManager] enumeratorAtURL:url
			includingPropertiesForKeys:@[]
			options:NSDirectoryEnumerationSkipsHiddenFiles
			errorHandler:nil];
			NSURL *url;
			while(url=[enumerator nextObject])
			{
				NSNumber *isfile;
				[url getResourceValue:&isfile forKey:NSURLIsRegularFileKey error:NULL];
				if(isfile.boolValue)
				{
					[files addObject:url.path];
				}
			}
		}
		else
		{
			[files addObject:filename];
		}


		[pool release];
	}

	return [NSArray arrayWithArray:files];
}
