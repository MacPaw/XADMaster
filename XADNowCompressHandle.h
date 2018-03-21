/*
 * XADNowCompressHandle.h
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

@interface XADNowCompressHandle:CSBlockStreamHandle
{
	NSMutableArray *files;
	int nextfile;

	struct
	{
		uint32_t offset,length;
		int flags;
	} *blocks;
	int maxblocks,numblocks,nextblock;

	uint8_t inblock[0x8000],outblock[0x10000],dictionarycache[0x8000];
}

-(id)initWithHandle:(CSHandle *)handle files:(NSMutableArray *)filesarray;

-(void)resetBlockStream;

-(BOOL)parseAndCheckFileHeaderWithHeaderOffset:(uint32_t)headeroffset
firstOffset:(uint32_t)firstoffset delta:(int32_t)delta;
-(int)findFileHeaderDeltaWithHeaderOffset:(uint32_t)headeroffset firstOffset:(uint32_t)firstoffset;
-(BOOL)readNextFileHeader;
-(int)produceBlockAtOffset:(off_t)pos;

@end
