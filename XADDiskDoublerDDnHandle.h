/*
 * XADDiskDoublerDDnHandle.h
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

@interface XADDiskDoublerDDnHandle:XADLZSSHandle
{
	int blocksize;
	off_t blockend;
	int literalsleft;

	int correctxor;

	XADPrefixCode *lengthcode;

	uint8_t buffer[0x10000];
	uint8_t *literalptr;
	uint16_t *offsetptr;
	off_t nextblock;

	BOOL checksumcorrect,uncompressed;
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length;
-(void)dealloc;

-(void)resetLZSSHandle;
-(int)nextLiteralOrOffset:(int *)offsetptr andLength:(int *)lengthptr atPosition:(off_t)pos;
-(void)readBlockAtPosition:(off_t)pos;
-(XADPrefixCode *)readCode;

-(BOOL)hasChecksum;
-(BOOL)isChecksumCorrect;

@end
