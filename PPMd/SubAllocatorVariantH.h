/*
 * SubAllocatorVariantH.h
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
#ifndef __PPMD_SUB_ALLOCATOR_VARIANT_H_H__
#define __PPMD_SUB_ALLOCATOR_VARIANT_H_H__

#include "SubAllocator.h"

struct PPMdMemoryBlockVariantH
{
	uint16_t Stamp,NU;
	uint32_t next,prev;
} __attribute__((packed));

typedef struct PPMdSubAllocatorVariantH
{
	PPMdSubAllocator core;

	uint32_t SubAllocatorSize;
	uint8_t Index2Units[38],Units2Index[128],GlueCount;
	uint8_t *pText,*UnitsStart,*LowUnit,*HighUnit;
	struct PPMAllocatorNodeVariantH { struct PPMAllocatorNodeVariantH *next; } FreeList[38];
	struct PPMdMemoryBlockVariantH sentinel;
	uint8_t HeapStart[0];
} PPMdSubAllocatorVariantH;

PPMdSubAllocatorVariantH *CreateSubAllocatorVariantH(int size);
void FreeSubAllocatorVariantH(PPMdSubAllocatorVariantH *self);

#endif
