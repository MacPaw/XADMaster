/*
 * XADStuffItXDarkhorseHandle.h
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
#import "CarrylessRangeCoder.h"

@interface XADStuffItXDarkhorseHandle:XADLZSSHandle
{
	CarrylessRangeCoder coder;

	int next;

	uint32_t flagweights[4],flagweight2;
	uint32_t litweights[16][256],litweights2[16][256][2];
	uint32_t recencyweight1,recencyweight2,recencyweight3,recencyweights[4];
	uint32_t lenweight,shortweights[4][16],longweights[256];
	uint32_t distlenweights[4][64],distweights[10][32],distlowbitweights[16];

	int distancetable[4];
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length windowSize:(int)windowsize;

-(void)resetLZSSHandle;
-(int)nextLiteralOrOffset:(int *)offset andLength:(int *)length atPosition:(off_t)pos;

-(int)readLiteralWithPrevious:(int)prev next:(int)next;
-(int)readLengthWithIndex:(int)index;
-(int)readDistanceWithLength:(int)len;
-(int)readRecencyWithIndex:(int)index;

-(int)readSymbolWithWeights:(uint32_t *)weights numberOfBits:(int)num;

-(void)updateDistanceMemoryWithOldIndex:(int)oldindex distance:(int)distance;

@end
