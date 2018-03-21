/*
 * XADRARAESHandle.h
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

@interface XADRARAESHandle:CSStreamHandle
{
	off_t startoffs;

	aes_decrypt_ctx aes;
	uint8_t iv[16],block[16],blockbuffer[16];
}

+(NSData *)keyForPassword:(NSString *)password salt:(NSData *)salt brokenHash:(BOOL)brokenhash;

-(id)initWithHandle:(CSHandle *)handle key:(NSData *)keydata;
-(id)initWithHandle:(CSHandle *)handle length:(off_t)length key:(NSData *)keydata;
-(id)initWithHandle:(CSHandle *)handle RAR5Key:(NSData *)keydata IV:(NSData *)ivdata;
-(id)initWithHandle:(CSHandle *)handle length:(off_t)length RAR5Key:(NSData *)keydata IV:(NSData *)ivdata;

-(void)resetStream;
-(int)streamAtMost:(int)num toBuffer:(void *)buffer;

@end
