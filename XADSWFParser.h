/*
 * XADSWFParser.h
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
#import "XADSWFTagParser.h"

@interface XADSWFParser:XADArchiveParser
{
	XADSWFTagParser *parser;
	NSMutableArray *dataobjects;
}

-(id)init;
-(void)dealloc;

+(int)requiredHeaderSize;
+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name;

-(void)parse;

-(NSData *)createWAVHeaderForFlags:(int)flags length:(int)length;

-(void)addEntryWithName:(NSString *)name data:(NSData *)data;
-(void)addEntryWithName:(NSString *)name
offset:(off_t)offset length:(off_t)length;
-(void)addEntryWithName:(NSString *)name data:(NSData *)data
offset:(off_t)offset length:(off_t)length;
-(void)addEntryWithName:(NSString *)name losslessFormat:(int)format
width:(int)width height:(int)height alpha:(BOOL)alpha
offset:(off_t)offset length:(off_t)length;

-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum;
-(NSData *)convertLosslessFormat:(int)format width:(int)width height:(int)height
alpha:(BOOL)alpha handle:(CSHandle *)handle;

-(NSString *)formatName;

@end
