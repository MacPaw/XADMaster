/*
 * XADISO9660Parser.h
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

@interface XADISO9660Parser:XADArchiveParser
{
	int blocksize;
	BOOL isjoliet,ishighsierra;
	CSHandle *fh;
}

+(int)requiredHeaderSize;
+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data
name:(NSString *)name propertiesToAdd:(NSMutableDictionary *)props;

-(id)init;
-(void)dealloc;

-(void)parse;
-(void)parseVolumeDescriptorAtBlock:(uint32_t)block;
-(void)parseDirectoryWithPath:(XADPath *)path atBlock:(uint32_t)block length:(uint32_t)length;

-(XADString *)readStringOfLength:(int)length;
-(NSDate *)readLongDateAndTime;
-(NSDate *)readShortDateAndTime;
-(NSDate *)parseDateAndTimeWithBytes:(const uint8_t *)buffer long:(BOOL)islong;
-(NSDate *)parseLongDateAndTimeWithBytes:(const uint8_t *)buffer;
-(NSDate *)parseShortDateAndTimeWithBytes:(const uint8_t *)buffer;

-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum;
-(NSString *)formatName;

@end
