/*
 * XAD7ZipBranchHandles.h
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

@interface XAD7ZipBranchHandle:CSBlockStreamHandle
{
	off_t startoffs;
	uint8_t inbuffer[4096];
	int leftoverstart,leftoverlength;
	uint32_t baseoffset;
}

-(id)initWithHandle:(CSHandle *)handle;
-(id)initWithHandle:(CSHandle *)handle propertyData:(NSData *)propertydata;
-(id)initWithHandle:(CSHandle *)handle length:(off_t)length;
-(id)initWithHandle:(CSHandle *)handle length:(off_t)length propertyData:(NSData *)propertydata;

-(void)resetBlockStream;
-(int)produceBlockAtOffset:(off_t)pos;

-(int)decodeBlock:(uint8_t *)block length:(int)length offset:(off_t)pos;

@end

@interface XAD7ZipBCJHandle:XAD7ZipBranchHandle { uint32_t state; }
@end

@interface XAD7ZipPPCHandle:XAD7ZipBranchHandle {}
@end

@interface XAD7ZipIA64Handle:XAD7ZipBranchHandle {}
@end

@interface XAD7ZipARMHandle:XAD7ZipBranchHandle {}
@end

@interface XAD7ZipThumbHandle:XAD7ZipBranchHandle {}
@end

@interface XAD7ZipSPARCHandle:XAD7ZipBranchHandle {}
@end
