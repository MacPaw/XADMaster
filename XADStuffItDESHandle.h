/*
 * XADStuffItDESHandle.h
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

@interface XADStuffItDESHandle:CSBlockStreamHandle
{
	uint8_t block[8];
	uint32_t A,B,C,D;
}

+(NSData *)keyForPasswordData:(NSData *)passworddata entryKey:(NSData *)entrykey MKey:(NSData *)mkey;

-(id)initWithHandle:(CSHandle *)handle key:(NSData *)keydata;
-(id)initWithHandle:(CSHandle *)handle length:(off_t)length key:(NSData *)keydata;

-(int)produceBlockAtOffset:(off_t)pos;

@end
