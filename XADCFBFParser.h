/*
 * XADCFBFParser.h
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

@interface XADCFBFParser:XADArchiveParser
{
	int minsize,secsize,minisecsize;

	uint32_t rootdirectorynode,firstminisector;

	int numsectors,numminisectors;
	uint32_t *sectable,*minisectable;
	bool *secvisitedtable;
}

+(int)requiredHeaderSize;
+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name;

-(void)parse;
-(XADString *)decodeFileNameWithBytes:(uint8_t *)bytes length:(int)length;
-(void)processEntry:(uint32_t)n atPath:(XADPath *)path entries:(NSArray *)entries;
-(void)seekToSector:(uint32_t)sector;
-(uint32_t)nextSectorAfter:(uint32_t)sector;

-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum;
-(NSString *)formatName;

@end
