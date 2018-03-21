/*
 * SubAllocatorVariantI.h
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
#ifndef __PPMD_SUB_ALLOCATOR_VARIANT_I_H__
#define __PPMD_SUB_ALLOCATOR_VARIANT_I_H__

#include "SubAllocator.h"

typedef struct PPMdMemoryBlockVariantI
{
	uint32_t Stamp;
	uint32_t next;
	uint32_t NU;
} __attribute__((packed)) PPMdMemoryBlockVariantI;

typedef struct PPMdSubAllocatorVariantI
{
	PPMdSubAllocator core;

	uint32_t GlueCount,SubAllocatorSize;
	uint8_t Index2Units[38],Units2Index[128]; // constants
	uint8_t *pText,*UnitsStart,*LowUnit,*HighUnit;
	PPMdMemoryBlockVariantI BList[38];
	uint8_t HeapStart[0];
} PPMdSubAllocatorVariantI;

PPMdSubAllocatorVariantI *CreateSubAllocatorVariantI(int size);
void FreeSubAllocatorVariantI(PPMdSubAllocatorVariantI *self);

uint32_t GetUsedMemoryVariantI(PPMdSubAllocatorVariantI *self);
void SpecialFreeUnitVariantI(PPMdSubAllocatorVariantI *self,uint32_t offs);
uint32_t MoveUnitsUpVariantI(PPMdSubAllocatorVariantI *self,uint32_t oldoffs,int num);
void ExpandTextAreaVariantI(PPMdSubAllocatorVariantI *self);

#endif
