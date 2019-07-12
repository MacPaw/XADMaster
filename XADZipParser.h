/*
 * XADZipParser.h
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
#import "XADMacArchiveParser.h"

typedef struct XADZipParserCentralDirectoryRecord
{
    //central file header signature    4 bytes  (0x02014b50)
    uint32_t centralid;

    // version made by                 2 bytes (crateor 1 byte and system - 1 bye)
    int creatorversion;
    int system;

    // version needed to extract       2 bytes
    int extractversion;

    // general purpose bit flag        2 bytes
    int flags;

    // compression method              2 bytes
    int compressionmethod;

    // last mod file time              2 bytes
    // last mod file date              2 bytes
    uint32_t date;

    // crc-32                          4 bytes
    uint32_t crc;

    // compressed size                 4 bytes
    off_t compsize;

    // uncompressed size               4 bytes
    off_t uncompsize;

    // file name length                2 bytes
    int namelength;

    // extra field length              2 bytes
    int extralength;

    // file comment length             2 bytes
    int commentlength;

    // disk number start               2 bytes
    int startdisk;

    // internal file attributes        2 bytes
    int infileattrib;

    // external file attributes        4 bytes
    uint32_t extfileattrib;

    // relative offset of local header 4 bytes
    off_t locheaderoffset;
} XADZipParserCentralDirectoryRecord;

@interface XADZipParser:XADMacArchiveParser
{
	NSMutableDictionary *prevdict;
	NSData *prevname;
}

+(int)requiredHeaderSize;
+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name;
+(NSArray *)volumesForHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name;

-(id)init;
-(void)dealloc;

-(void)parseWithSeparateMacForks;
-(void)parseWithCentralDirectoryAtOffset:(off_t)centraloffs zip64Offset:(off_t)zip64offs;
-(off_t)offsetForVolume:(int)disk offset:(off_t)offset;
-(void)findCentralDirectoryRecordOffset:(off_t *)centrOffset zip64Offset:(off_t *)zip64offs;

-(void)parseWithoutCentralDirectory;
-(void)findEndOfStreamMarkerWithZip64Flag:(BOOL)zip64 uncompressedSizePointer:(off_t *)uncompsizeptr
compressedSizePointer:(off_t *)compsizeptr CRCPointer:(uint32_t *)crcptr;
-(void)findNextEntry;

//-(void)findNextZipMarkerStartingAt:(off_t)startpos;
//-(void)findNoSeekMarkerForDictionary:(NSMutableDictionary *)dict;
-(NSDictionary *)parseZipExtraWithLength:(int)length nameData:(NSData *)namedata
uncompressedSizePointer:(off_t *)uncompsizeptr compressedSizePointer:(off_t *)compsizeptr;
-(XADZipParserCentralDirectoryRecord)readCentralDirectoryRecord;

-(void)addZipEntryWithSystem:(int)system
extractVersion:(int)extractversion
flags:(int)flags
compressionMethod:(int)compressionmethod
date:(uint32_t)date
crc:(uint32_t)crc
localDate:(uint32_t)localdate
compressedSize:(off_t)compsize
uncompressedSize:(off_t)uncompsize
extendedFileAttributes:(uint32_t)extfileattrib
extraDictionary:(NSDictionary *)extradict
dataOffset:(off_t)dataoffset
nameData:(NSData *)namedata
commentData:(NSData *)commentdata
isLastEntry:(BOOL)islastentry;

-(void)rememberEntry:(NSMutableDictionary *)dict withName:(NSData *)namedata;
-(void)addRemeberedEntryAndForget;

-(CSHandle *)rawHandleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum;
-(CSHandle *)decompressionHandleWithHandle:(CSHandle *)parent method:(int)method flags:(int)flags size:(off_t)size;

-(NSString *)formatName;

@end
