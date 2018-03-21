/*
 * XADCABBlockReader.h
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

@interface XADCABBlockReader:NSObject
{
	CSHandle *parent;
	int extbytes;

	int numfolders;
	off_t offsets[100];
	int numblocks[100];

	int currentfolder,currentblock;

	off_t complen,uncomplen;
}

-(id)initWithHandle:(CSHandle *)handle reservedBytes:(int)reserved;
-(void)dealloc;

-(void)addFolderAtOffset:(off_t)startoffs numberOfBlocks:(int)numblocks;
-(void)scanLengths;

-(CSHandle *)handle;
-(off_t)compressedLength;
-(off_t)uncompressedLength;

-(void)restart;
-(BOOL)readNextBlockToBuffer:(uint8_t *)buffer compressedLength:(int *)compptr
uncompressedLength:(int *)uncompptr;

@end
