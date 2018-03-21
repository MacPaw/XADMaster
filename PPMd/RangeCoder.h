/*
 * RangeCoder.h
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
#ifndef __PPMD_RANGE_CODER_H__
#define __PPMD_RANGE_CODER_H__

#include <stdint.h>
#include <stdbool.h>

typedef int PPMdReadFunction(void *context);

typedef struct PPMdRangeCoder
{
	PPMdReadFunction *readfunc;
	void *inputcontext;

	uint32_t low,code,range,bottom;
	bool uselow;
} PPMdRangeCoder;

void InitializePPMdRangeCoder(PPMdRangeCoder *self,
PPMdReadFunction *readfunc,void *inputcontext,
bool uselow,int bottom);

uint32_t PPMdRangeCoderCurrentCount(PPMdRangeCoder *self,uint32_t scale);
void RemovePPMdRangeCoderSubRange(PPMdRangeCoder *self,uint32_t lowcount,uint32_t highcount);

int NextWeightedBitFromPPMdRangeCoder(PPMdRangeCoder *self,int weight,int size);

int NextWeightedBitFromPPMdRangeCoder2(PPMdRangeCoder *self,int weight,int shift);

void NormalizePPMdRangeCoder(PPMdRangeCoder *self);

#endif
