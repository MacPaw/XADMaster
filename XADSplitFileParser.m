/*
 * XADSplitFileParser.m
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
#import "XADSplitFileParser.h"
#import "XADRegex.h"
#import "XADPlatform.h"
#import "CSFileHandle.h"

@implementation XADSplitFileParser

+(int)requiredHeaderSize { return 0; }

+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name
{
	if(!name) return NO;
	if(![handle isKindOfClass:[CSFileHandle class]]) return NO;

	// Check if filename is of the form .001
	NSArray *matches=[name substringsCapturedByPattern:@"^(.*)\\.([0-9]{3})$" options:REG_ICASE];
	if(!matches) return NO;

	// Find another filename in the series. Pick .001 if the given file is not already that,
	// and .002 otherwise.
	NSString *otherext;
	if([[matches objectAtIndex:2] isEqual:@"001"]) otherext=@"002";
	else otherext=@"001";

	// Check if this other file exists, too.
	NSString *othername=[NSString stringWithFormat:@"%@.%@",[matches objectAtIndex:1],otherext];
	return [XADPlatform fileExistsAtPath:othername];
}

+(NSArray *)volumesForHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name
{
	NSArray *matches=[name substringsCapturedByPattern:@"^(.*)\\.[0-9]{3}$" options:REG_ICASE];
	if(matches)
	{
		return [self scanForVolumesWithFilename:name
		regex:[XADRegex regexWithPattern:[NSString stringWithFormat:@"^%@\\.[0-9]{3}$",
			[[matches objectAtIndex:1] escapedPattern]] options:REG_ICASE]
		firstFileExtension:nil];
	}

	return nil;
}

-(void)parse
{
	NSString *basename=[[self name] stringByDeletingPathExtension];
	CSHandle *handle=[self handle];

	NSMutableDictionary *dict=[NSMutableDictionary dictionaryWithObjectsAndKeys:
		[self XADPathWithUnseparatedString:basename],XADFileNameKey,
		[NSNumber numberWithLongLong:[handle fileSize]],XADFileSizeKey,
		[NSNumber numberWithLongLong:[handle fileSize]],XADCompressedSizeKey,
	nil];

	NSString *ext=[basename pathExtension];
	if([ext caseInsensitiveCompare:@"zip"]==0)
	[dict setObject:[NSNumber numberWithBool:YES] forKey:XADIsArchiveKey];

	[self addEntryWithDictionary:dict];
}

-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum
{
	CSHandle *handle=[self handle];
	[handle seekToFileOffset:0];
	return handle;
}

-(NSString *)formatName { return @"Split file"; }

@end
