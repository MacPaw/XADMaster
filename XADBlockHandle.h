/*
 * XADBlockHandle.h
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
#import "CSHandle.h"

@interface XADBlockHandle:CSHandle
{
	off_t currpos,length;

	int numblocks,blocksize;
	off_t *blockoffsets;
}

-(id)initWithHandle:(CSHandle *)handle blockSize:(int)size;
-(id)initWithHandle:(CSHandle *)handle length:(off_t)maxlength blockSize:(int)size;
-(void)dealloc;

//-(void)addBlockAt:(off_t)start;
-(void)setBlockChain:(uint32_t *)blocktable numberOfBlocks:(int)totalblocks
firstBlock:(uint32_t)first headerSize:(off_t)headersize;

-(off_t)fileSize;
-(off_t)offsetInFile;
-(BOOL)atEndOfFile;

-(void)seekToFileOffset:(off_t)offs;
-(void)seekToEndOfFile;
-(int)readAtMost:(int)num toBuffer:(void *)buffer;

@end
