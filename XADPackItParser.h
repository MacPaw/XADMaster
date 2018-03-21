/*
 * XADPackItParser.h
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
#import "CSBlockStreamHandle.h"

#import "Crypto/des.h"

@interface XADPackItParser:XADArchiveParser
{
	NSMutableDictionary *currdesc;
	CSHandle *currhandle;
}

+(int)requiredHeaderSize;
+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name;

-(void)parse;
-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum;
-(CSHandle *)handleForSolidStreamWithObject:(id)obj wantChecksum:(BOOL)checksum;
-(NSString *)formatName;

@end

@interface XADPackItXORHandle:CSBlockStreamHandle
{
	uint8_t key[8],block[8];
}

-(id)initWithHandle:(CSHandle *)handle password:(NSData *)passdata;
-(id)initWithHandle:(CSHandle *)handle length:(off_t)length password:(NSData *)passdata;

-(int)produceBlockAtOffset:(off_t)pos;

@end

@interface XADPackItDESHandle:CSBlockStreamHandle
{
	uint8_t block[8];
	DES_key_schedule schedule;
}

-(id)initWithHandle:(CSHandle *)handle password:(NSData *)passdata;
-(id)initWithHandle:(CSHandle *)handle length:(off_t)length password:(NSData *)passdata;

-(int)produceBlockAtOffset:(off_t)pos;

@end
