/*
 * XADCRCSuffixHandle.h
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
#import "Checksums.h"
#import "Progress.h"
#import "CRC.h"

@interface XADCRCSuffixHandle:CSStreamHandle
{
	CSHandle *crcparent;

	int crcsize;
	BOOL bigend;
	uint32_t crc,initcrc,compcrc;
	const uint32_t *table;

	BOOL didtest,wascorrect;
}

+(XADCRCSuffixHandle *)IEEECRC32SuffixHandleWithHandle:(CSHandle *)handle CRCHandle:(CSHandle *)crchandle
bigEndianCRC:(BOOL)bigendian conditioned:(BOOL)conditioned;
+(XADCRCSuffixHandle *)CCITTCRC16SuffixHandleWithHandle:(CSHandle *)handle CRCHandle:(CSHandle *)crchandle
bigEndianCRC:(BOOL)bigendian conditioned:(BOOL)conditioned;

-(id)initWithHandle:(CSHandle *)handle CRCHandle:(CSHandle *)crchandle initialCRC:(uint32_t)initialcrc
CRCSize:(int)crcbytes bigEndianCRC:(BOOL)bigendian CRCTable:(const uint32_t *)crctable;
-(void)dealloc;

-(void)resetStream;
-(int)streamAtMost:(int)num toBuffer:(void *)buffer;

-(BOOL)hasChecksum;
-(BOOL)isChecksumCorrect;

@end

