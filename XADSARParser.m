/*
 * XADSARParser.m
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
#import "XADSARParser.h"
#import "XADRegex.h"

@implementation XADSARParser

+(int)requiredHeaderSize { return 6; }

+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name
{
	if(!name) return NO;
	if(![[name lastPathComponent] matchedByPattern:@"^arc[0-9]*\\.sar$" options:REG_ICASE]) return NO;

	//const uint8_t *bytes=[data bytes];
	//int length=[data length];

	return YES;
}

-(void)parse
{
	CSHandle *fh=[self handle];

	int numfiles=[fh readUInt16BE];
	if(numfiles==0) numfiles=[fh readUInt16BE];

	uint32_t offset=[fh readUInt32BE];

	for(int i=0;i<numfiles && [self shouldKeepParsing];i++)
	{
		NSMutableData *namedata=[NSMutableData data];
		uint8_t c;
		while((c=[fh readUInt8])) [namedata appendBytes:&c length:1];

		uint32_t dataoffs=[fh readUInt32BE];
		uint32_t datalen=[fh readUInt32BE];

		NSMutableDictionary *dict=[NSMutableDictionary dictionaryWithObjectsAndKeys:
			[self XADPathWithData:namedata separators:XADWindowsPathSeparator],XADFileNameKey,
			[NSNumber numberWithUnsignedLong:datalen],XADFileSizeKey,
			[NSNumber numberWithUnsignedLong:datalen],XADCompressedSizeKey,
			[NSNumber numberWithUnsignedLong:datalen],XADDataLengthKey,
			[NSNumber numberWithUnsignedLong:dataoffs+offset],XADDataOffsetKey,
			[self XADStringWithString:@"None"],XADCompressionNameKey,
		nil];

		[self addEntryWithDictionary:dict retainPosition:YES];
	}
}

-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum
{
	return [self handleAtDataOffsetForDictionary:dict];
}

-(NSString *)formatName { return @"SAR"; }

@end
