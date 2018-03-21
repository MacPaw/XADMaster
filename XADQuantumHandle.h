/*
 * XADQuantumHandle.h
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
#import "LZSS.h"

typedef struct QuantumCoder
{
	uint16_t CS_L,CS_H,CS_C;
	CSInputBuffer *input;
} QuantumCoder;

typedef struct QuantumModelSymbol
{
	uint16_t symbol;
	uint16_t cumfreq;
} QuantumModelSymbol;

typedef struct QuantumModel
{
	int numsymbols,shiftsleft; 
	QuantumModelSymbol symbols[65];
} QuantumModel;

@interface XADQuantumHandle:XADCABBlockHandle
{
	LZSS lzss;

	int numslots4,numslots5,numslots6;

	QuantumCoder coder;
	QuantumModel selectormodel;
	QuantumModel literalmodel[4];
	QuantumModel offsetmodel4,offsetmodel5,offsetmodel6;
	QuantumModel lengthmodel6;
}

-(id)initWithBlockReader:(XADCABBlockReader *)blockreader windowBits:(int)windowbits;

-(void)resetCABBlockHandle;
-(int)produceCABBlockWithInputBuffer:(uint8_t *)buffer length:(int)length atOffset:(off_t)pos length:(int)uncomplength;

@end

