/*
 * XADWARCParser.h
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

@interface XADWARCParser:XADArchiveParser
{
}

+(int)requiredHeaderSize;
+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name;

-(void)parse;
-(NSMutableDictionary *)parseHTTPHeadersWithHandle:(CSHandle *)handle;
-(NSArray *)readHTTPHeadersWithHandle:(CSHandle *)handle;

-(NSString *)getTargetURI:(NSDictionary *)record;
-(NSArray *)pathComponentsForURLString:(NSString *)urlstring;
-(NSMutableDictionary *)insertDirectory:(NSString *)name inDirectory:(NSMutableDictionary *)dir;
-(void)insertFile:(NSString *)name record:(NSMutableDictionary *)record inDirectory:(NSMutableDictionary *)dir;
-(void)buildXADPathsForFilesInDirectory:(NSMutableDictionary *)dir parentPath:(XADPath *)parent;

-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum;
-(NSString *)formatName;

@end
