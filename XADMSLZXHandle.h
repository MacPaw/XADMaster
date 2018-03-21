/*
 * XADMSLZXHandle.h
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
#import "XADCABBlockHandle.h"
#import "XADPrefixCode.h"
#import "LZSS.h"

@interface XADMSLZXHandle:XADCABBlockHandle
{
	LZSS lzss;

	XADPrefixCode *maincode,*lengthcode,*offsetcode;

	int numslots;
	BOOL headerhasbeenread,ispreprocessed;
	int32_t preprocesssize;

	off_t inputpos;

	int blocktype;
	off_t blockend;
	int r0,r1,r2;
	int mainlengths[256+50*8],lengthlengths[249];

	uint8_t outbuffer[32768];
}

-(id)initWithBlockReader:(XADCABBlockReader *)blockreader windowBits:(int)windowbits;
-(void)dealloc;

-(void)resetCABBlockHandle;
-(int)produceCABBlockWithInputBuffer:(uint8_t *)buffer length:(int)length atOffset:(off_t)pos length:(int)uncomplength;

-(void)readBlockHeaderAtPosition:(off_t)pos;
-(void)readDeltaLengths:(int *)lengths count:(int)count alternateMode:(BOOL)altmode;

@end
