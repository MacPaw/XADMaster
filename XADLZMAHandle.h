/*
 * XADLZMAHandle.h
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
#import "CSStreamHandle.h"

#if !__LP64__
#define _LZMA_UINT32_IS_ULONG
#endif

#define Byte LzmaByte
#define UInt16 LzmaUInt16
#define UInt32 LzmaUInt32
#define UInt64 LzmaUInt64
#import "lzma/LzmaDec.h"
#undef Byte
#undef UInt32
#undef UInt16
#undef UInt64

@interface XADLZMAHandle:CSStreamHandle
{
	off_t startoffs;

	CLzmaDec lzma;

	uint8_t inbuffer[16*1024];
	int bufbytes,bufoffs;
}

-(id)initWithHandle:(CSHandle *)handle propertyData:(NSData *)propertydata;
-(id)initWithHandle:(CSHandle *)handle length:(off_t)length propertyData:(NSData *)propertydata;
-(void)dealloc;

-(void)resetStream;
-(int)streamAtMost:(int)num toBuffer:(void *)buffer;

@end
