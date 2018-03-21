/*
 * XAD7ZipAESHandle.h
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

#import "CSBlockStreamHandle.h"

#import "Crypto/aes.h"

@interface XAD7ZipAESHandle:CSBlockStreamHandle
{
	off_t startoffs;

	aes_decrypt_ctx aes;
	uint8_t iv[16],block[16],buffer[65536];
}

+(int)logRoundsForPropertyData:(NSData *)propertydata;
+(NSData *)saltForPropertyData:(NSData *)propertydata;
+(NSData *)IVForPropertyData:(NSData *)propertydata;
+(NSData *)keyForPassword:(NSString *)password salt:(NSData *)salt logRounds:(int)logrounds;

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length key:(NSData *)keydata IV:(NSData *)ivdata;

-(void)resetBlockStream;
-(int)produceBlockAtOffset:(off_t)pos;

@end
