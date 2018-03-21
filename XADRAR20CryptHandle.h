/*
 * XADRAR20CryptHandle.h
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

@interface XADRAR20CryptHandle:CSBlockStreamHandle
{
	off_t startoffs;
	NSData *password;

	uint8_t outblock[16];
    uint32_t key[4];
	uint8_t table[256];
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length password:(NSData *)passdata;
-(void)dealloc;

-(void)resetBlockStream;
-(void)calculateKey;
-(int)produceBlockAtOffset:(off_t)pos;

@end
