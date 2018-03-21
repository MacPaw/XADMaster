/*
 * CarrylessRangeCoder.h
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
#import "CSInputBuffer.h"

typedef struct CarrylessRangeCoder
{
	CSInputBuffer *input;
	uint32_t low,code,range,bottom;
	BOOL uselow;
} CarrylessRangeCoder;

void InitializeRangeCoder(CarrylessRangeCoder *self,CSInputBuffer *input,BOOL uselow,int bottom);

uint32_t RangeCoderCurrentCount(CarrylessRangeCoder *self,uint32_t scale);
void RemoveRangeCoderSubRange(CarrylessRangeCoder *self,uint32_t lowcount,uint32_t highcount);

int NextSymbolFromRangeCoder(CarrylessRangeCoder *self,uint32_t *freqtable,int numfreq);
int NextBitFromRangeCoder(CarrylessRangeCoder *self);
int NextWeightedBitFromRangeCoder(CarrylessRangeCoder *self,int weight,int size);

int NextWeightedBitFromRangeCoder2(CarrylessRangeCoder *self,int weight,int shift);

void NormalizeRangeCoder(CarrylessRangeCoder *self);
