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

typedef enum {
    RAR5ArchiveFlagsNone                   = 0,
    RAR5ArchiveFlagsVolume                 = 0x0001, // Volume. Archive is a part of multivolume set.
    RAR5ArchiveFlagsVolumeNumberPresent    = 0x0002, // Volume number field is present.
                                                     // This flag is present in all volumes except first.
    RAR5ArchiveFlagsSolid                  = 0x0004, // Solid archive.
    RAR5ArchiveFlagsRecoveryRecordPresent  = 0x0008, // Recovery record is present.
    RAR5ArchiveFlagsLocked                 = 0x0010, // Locked archive.
} RAR5ArchiveFlags;

typedef enum {
   RAR5HeaderTypeUnknown    =  0,
   RAR5HeaderTypeMain       =  1, //   Main archive header.
   RAR5HeaderTypeFile       =  2, //   File header.
   RAR5HeaderTypeService    =  3, //   Service header.
   RAR5HeaderTypeEncryption =  4, //   Archive encryption header.
   RAR5HeaderTypeEnd        =  5, //   End of archive header.
} RAR5HeaderType;

typedef struct RAR5HeaderBlock
{
    RAR5Block block;
    RAR5ArchiveFlags archiveFlags;
} RAR5HeaderBlock;


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

@interface XADRAR5Parser(Testing)
+(uint64_t)readRAR5VIntFrom:(CSHandle *)handle;
@end

