/*
 * XADStuffItArsenicHandle.h
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
#import "BWT.h"

typedef struct ArithmeticSymbol
{
	int symbol;
	int frequency;
} ArithmeticSymbol;

typedef struct ArithmeticModel
{
	int totalfrequency;
	int increment;
	int frequencylimit;

	int numsymbols;
	ArithmeticSymbol symbols[128];
} ArithmeticModel;

typedef struct ArithmeticDecoder
{
	CSInputBuffer *input;
	int range,code;
} ArithmeticDecoder;



@interface XADStuffItArsenicHandle:CSByteStreamHandle
{
	ArithmeticModel initialmodel,selectormodel,mtfmodel[7];
	ArithmeticDecoder decoder;
	MTFState mtf;

	int blockbits,blocksize;
	uint8_t *block;
	BOOL endofblocks;

	int numbytes,bytecount,transformindex;
	uint32_t *transform;

	int randomized,randcount,randindex;

	int repeat,count,last;

	uint32_t crc,compcrc;
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length;
-(void)dealloc;

//-(void)resetBlockStream;
//-(int)produceBlockAtOffset:(off_t)pos;
-(void)resetByteStream;
-(void)readBlock;
-(uint8_t)produceByteAtOffset:(off_t)pos;

-(BOOL)hasChecksum;
-(BOOL)isChecksumCorrect;

@end
