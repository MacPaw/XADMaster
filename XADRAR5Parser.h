/*
 * XADRAR5Parser.h
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

typedef struct RAR5Block
{
	uint32_t crc;
	uint64_t headersize,type,flags;
	uint64_t extrasize,datasize;
	off_t start,outerstart;
	CSHandle *fh;
} RAR5Block;

@interface XADRAR5Parser:XADArchiveParser
{
	NSData *headerkey;
	NSMutableDictionary *cryptocache;

	NSMutableArray *solidstreams,*currsolidstream;
	off_t totalsolidsize;
}

+(int)requiredHeaderSize;
+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name;
+(NSArray *)volumesForHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name;

-(void)parse;
-(void)addEntryWithDictionary:(NSMutableDictionary *)dict
inputParts:(NSArray *)parts isCorrupted:(BOOL)iscorrupted;

-(NSMutableDictionary *)readFileBlockHeader:(RAR5Block)block;
-(RAR5Block)readBlockHeader;
-(void)skipBlock:(RAR5Block)block;
-(off_t)endOfBlockHeader:(RAR5Block)block;
-(NSData *)encryptionKeyForPassword:(NSString *)passwordstring salt:(NSData *)salt strength:(int)strength passwordCheck:(NSData *)check;
-(NSData *)hashKeyForPassword:(NSString *)passwordstring salt:(NSData *)salt strength:(int)strength passwordCheck:(NSData *)check;
-(NSDictionary *)keysForPassword:(NSString *)passwordstring salt:(NSData *)salt strength:(int)strength passwordCheck:(NSData *)check;

-(CSInputBuffer *)inputBufferWithDictionary:(NSDictionary *)dict;
-(CSHandle *)inputHandleWithDictionary:(NSDictionary *)dict;

-(NSString *)formatName;

@end

@interface XADEmbeddedRAR5Parser:XADRAR5Parser
{
}

-(NSString *)formatName;

@end

