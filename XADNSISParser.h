/*
 * XADNSISParser.h
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

typedef struct NSISVariableExpansion
{
	const char *variable,*expansion;
} NSISVariableExpansion;

@interface XADNSISParser:XADArchiveParser
{
	off_t base;
	CSHandle *solidhandle;
	int detectedformat,expansiontypes;

	XADPath *_outdir;
}

+(int)requiredHeaderSize;
+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data
name:(NSString *)name propertiesToAdd:(NSMutableDictionary *)props;

-(void)parse;

-(void)parseOlderFormat;
-(void)parseOldFormat;
-(void)parseNewFormat;

-(void)parseOpcodesWithHeader:(NSData *)header blocks:(NSDictionary *)blocks
extractOpcode:(int)extractopcode ignoreOverwrite:(BOOL)ignoreoverwrite
directoryOpcode:(int)diropcode directoryArgument:(int)dirarg assignOpcode:(int)assignopcode
startOffset:(int)startoffs endOffset:(int)endoffs stride:(int)stride
stringStartOffset:(int)stringoffs stringEndOffset:(int)stringendoffs unicode:(BOOL)unicode
newDateTimeOrder:(BOOL)neworder;
-(void)makeEntryArrayStrictlyIncreasing:(NSMutableArray *)array;

-(NSDictionary *)findBlocksWithHandle:(CSHandle *)fh;
-(int)findStringTableOffsetInData:(NSData *)data maxOffsets:(int)maxnumoffsets;
-(int)findOpcodeWithData:(NSData *)data blocks:(NSDictionary *)blocks
startOffset:(int)startoffs endOffset:(int)endoffs
stringStartOffset:(int)stringoffs stringEndOffset:(int)stringendoffs
opcodePossibilities:(int *)possibleopcodes count:(int)numpossibleopcodes
stridePossibilities:(int *)possiblestrides count:(int)numpossiblestrides
foundStride:(int *)strideptr foundPhase:(int *)phaseptr;
-(BOOL)isSectionedHeader:(NSData *)header;
-(BOOL)isUnicodeHeader:(NSData *)header stringStartOffset:(int)stringoffs stringEndOffset:(int)stringendoffs;

-(XADPath *)expandAnyPathWithOffset:(int)offset unicode:(BOOL)unicode header:(NSData *)header
stringStartOffset:(int)stringoffs stringEndOffset:(int)stringendoffs currentPath:(XADPath *)path;
-(XADPath *)expandPathWithOffset:(int)offset header:(NSData *)header
stringStartOffset:(int)stringoffs stringEndOffset:(int)stringendoffs currentPath:(XADPath *)path;
-(XADPath *)expandDollarVariablesWithBytes:(const uint8_t *)bytes length:(int)length currentPath:(XADPath *)path;
-(XADPath *)expandOldVariablesWithBytes:(const uint8_t *)bytes length:(int)length currentPath:(XADPath *)path;
-(XADPath *)expandNewVariablesWithBytes:(const uint8_t *)bytes length:(int)length currentPath:(XADPath *)path;
-(XADPath *)expandVariables:(NSISVariableExpansion *)expansions count:(int)count
bytes:(const uint8_t *)bytes length:(int)length currentPath:(XADPath *)dir;
-(XADPath *)expandUnicodePathWithOffset:(int)offset header:(NSData *)header
stringStartOffset:(int)stringoffs stringEndOffset:(int)stringendoffs currentPath:(XADPath *)dir;

-(CSHandle *)handleForBlockAtOffset:(off_t)offs;
-(CSHandle *)handleForBlockAtOffset:(off_t)offs length:(off_t)length;
-(CSHandle *)handleWithHandle:(CSHandle *)fh length:(off_t)length format:(int)format;
-(void)attemptSolidHandleAtPosition:(off_t)pos format:(int)format headerLength:(uint32_t)headerlength;
-(XADString *)compressionName;

-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum;
-(NSString *)formatName;

@end
