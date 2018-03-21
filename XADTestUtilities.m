/*
 * XADTestUtilities.m
 *
 * Copyright (c) 2017-present, MacPaw Inc. All rights reserved.
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
 * MA 02110-1301  USA
 */
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
