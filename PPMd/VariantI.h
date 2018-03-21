/*
 * VariantI.h
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
#ifndef __PPMD_VARIANT_I_H__
#define __PPMD_VARIANT_I_H__

#include "Context.h"
#include "SubAllocatorVariantI.h"

// PPMd Variant I. Used by WinZip.

#define MRM_RESTART 0
#define MRM_CUT_OFF 1
#define MRM_FREEZE 2

typedef struct PPMdModelVariantI
{
	PPMdCoreModel core;

	PPMdSubAllocatorVariantI *alloc;

	uint8_t NS2BSIndx[256],QTable[260]; // constants

	PPMdContext *MaxContext;
	int MaxOrder,MRMethod;
	SEE2Context SEE2Cont[24][32],DummySEE2Cont;
	uint16_t BinSumm[25][64]; // binary SEE-contexts

	bool endofstream;
} PPMdModelVariantI;

void StartPPMdModelVariantI(PPMdModelVariantI *self,
PPMdReadFunction *readfunc,void *inputcontext,
PPMdSubAllocatorVariantI *alloc,int maxorder,int restoration);
int NextPPMdVariantIByte(PPMdModelVariantI *self);

#endif
