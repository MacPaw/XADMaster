/*
 * XADLZXHandle.h
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
#import "XADLZSSHandle.h"
#import "XADPrefixCode.h"

@interface XADLZXHandle:XADLZSSHandle
{
	XADPrefixCode *maincode,*offsetcode;

	int blocktype,lastoffs;
	off_t blockend;
	int mainlengths[768];
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length;
-(void)dealloc;

-(void)resetLZSSHandle;
-(int)nextLiteralOrOffset:(int *)offset andLength:(int *)length atPosition:(off_t)pos;

-(void)readBlockHeaderAtPosition:(off_t)pos;
-(void)readDeltaLengths:(int *)lengths count:(int)count alternateMode:(BOOL)altmode;

@end


@interface XADLZXSwapHandle:CSByteStreamHandle
{
	uint8_t otherbyte;
}

-(id)initWithHandle:(CSHandle *)handle;

-(uint8_t)produceByteAtOffset:(off_t)pos;

@end
