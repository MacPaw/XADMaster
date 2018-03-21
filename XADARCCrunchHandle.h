/*
 * XADARCCrunchHandle.h
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
#import "CSByteStreamHandle.h"

typedef struct XADARCCrunchEntry
{
	BOOL used;
	uint8_t byte;
	int next;
	int parent;
} XADARCCrunchEntry;

@interface XADARCCrunchHandle:CSByteStreamHandle
{
	BOOL fast;

	int numfreecodes,sp,lastcode;
	uint8_t lastbyte;

	XADARCCrunchEntry table[4096];
	uint8_t stack[4096];
}

-(id)initWithHandle:(CSHandle *)handle useFastHash:(BOOL)usefast;
-(id)initWithHandle:(CSHandle *)handle length:(off_t)length useFastHash:(BOOL)usefast;

-(void)resetByteStream;
-(uint8_t)produceByteAtOffset:(off_t)pos;
-(void)updateTableWithParent:(int)parentcode byteValue:(int)byte;

@end
