/*
 * XADTest6.m
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
#import "XADArchiveParser.h"
#import "XADTestUtilities.h"
#import "NSStringPrinting.h"

NSMutableArray *reasons;
int failed=0;

@interface ArchiveTester:NSObject
{
}
@end

@implementation ArchiveTester

-(id)init
{
	if((self=[super init]))
	{
	}
	return self;
}

-(void)archiveParser:(XADArchiveParser *)parser
foundEntryWithDictionary:(NSDictionary *)dict
{
	NSNumber *dir=[dict objectForKey:XADIsDirectoryKey];
	CSHandle *fh=[parser handleForEntryWithDictionary:dict wantChecksum:YES];

	if(!dir||![dir boolValue])
	{
		if(!fh) failed++;
	}

	//[fh seekToEndOfFile];

	NSNumber *arch=[dict objectForKey:XADIsArchiveKey];
	if(arch&&[arch boolValue])
	{
		XADArchiveParser *parser=[XADArchiveParser archiveParserForHandle:fh
		name:[[dict objectForKey:XADFileNameKey] string]];

		[parser setDelegate:[[ArchiveTester new] autorelease]];
		[parser parse];
	}
}

-(void)archiveParser:(XADArchiveParser *)parser
findsFileInterestingForReason:(NSString *)reason
{
	[reasons addObject:reason];
}

-(BOOL)archiveParsingShouldStop:(XADArchiveParser *)parser
{
	return NO;
}

@end

int main(int argc,char **argv)
{
	int res=0;

	NSString *filename;
	NSEnumerator *enumerator=[FilesForArgs(argc,argv) objectEnumerator];
	while(filename=[enumerator nextObject])
	{
		NSAutoreleasePool *pool=[[NSAutoreleasePool alloc] init];

		reasons=[NSMutableArray array];
		failed=0;

		NSString *exception=nil;
		@try {
			XADArchiveParser *parser=[XADArchiveParser archiveParserForPath:filename];

			[parser setDelegate:[[ArchiveTester new] autorelease]];

			NSString *pass=FigureOutPassword(filename);
			if(pass) [parser setPassword:pass];

			[parser parse];
		} @catch(id e) {
			exception=[e description];
		}

		int count=[reasons count];
		if(count)
		{
			[[NSString stringWithFormat:
			@"The file \"%@\" was found to be interesting for the following %@:\n",
			filename,[reasons count]==1?@"reason":@"reasons"] print];

			for(int i=0;i<count;i++)
			{
				[[NSString stringWithFormat:@"* %@\n",
				[reasons objectAtIndex:i]] print];
			}

			res|=1;
		}

		if(failed)
		{
			[[NSString stringWithFormat:
			@"The file \"%@\" failed to extract %d %@\n",
			filename,failed,failed==1?@"entry":@"entries"] print];

			res|=2;
		}

		if(exception)
		{
			[[NSString stringWithFormat:
			@"The file \"%@\" threw exception \"%@\".\n",
			filename,exception] print];

			res|=2;
		}

		[pool release];
	}

	return res;
}
