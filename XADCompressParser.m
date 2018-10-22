/*
 * XADCompressParser.m
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
#import "XADCompressParser.h"
#import "XADCompressHandle.h"


@implementation XADCompressParser

+(int)requiredHeaderSize { return 3; }

+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name
{
	int length=[data length];
	const uint8_t *bytes=[data bytes];

	return length>=3&&bytes[0]==0x1f&&bytes[1]==0x9d;
}

-(void)parse
{
	CSHandle *fh=[self handle];

	[fh skipBytes:2];
	int flags=[fh readUInt8];

	NSString *contentname=[[self name] stringByDeletingPathExtension];

	NSMutableDictionary *dict=[NSMutableDictionary dictionaryWithObjectsAndKeys:
		[self XADPathWithUnseparatedString:contentname],XADFileNameKey,
		[self XADStringWithString:@"Compress"],XADCompressionNameKey,
		[NSNumber numberWithLongLong:3],XADDataOffsetKey,
		[NSNumber numberWithInt:flags],@"CompressFlags",
	nil];

	if([contentname matchedByPattern:@"\\.(tar|cpio|pax|warc)$" options:REG_ICASE])
	[dict setObject:[NSNumber numberWithBool:YES] forKey:XADIsArchiveKey];

	off_t size=[[self handle] fileSize];
	if(size!=CSHandleMaxLength)
	[dict setObject:[NSNumber numberWithLongLong:size-3] forKey:XADCompressedSizeKey];

	[self addEntryWithDictionary:dict];
}

-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum
{
	return [[[XADCompressHandle alloc] initWithHandle:[self handleAtDataOffsetForDictionary:dict]
	flags:[[dict objectForKey:@"CompressFlags"] intValue]] autorelease];
}

-(NSString *)formatName { return @"Compress"; }

@end
