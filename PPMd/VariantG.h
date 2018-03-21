/*
 * VariantG.h
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
#ifndef __PPMD_VARIANT_G_H__
#define __PPMD_VARIANT_G_H__

#include "Context.h"
#include <setjmp.h>

// PPMd Variant G. Used (slightly modified) by StuffIt X.

typedef struct PPMdModelVariantG
{
	PPMdCoreModel core;

	PPMdContext *MinContext,*MedContext,*MaxContext;
	int MaxOrder;
	bool Brimstone;
	SEE2Context SEE2Cont[43][8],DummySEE2Cont;
	uint8_t NS2BSIndx[256],NS2Indx[256];
	uint16_t BinSumm[128][16]; // binary SEE-contexts

	jmp_buf errorjmp;
} PPMdModelVariantG;

bool StartPPMdModelVariantG(PPMdModelVariantG *self,
PPMdReadFunction *readfunc,void *inputcontext,
PPMdSubAllocator *alloc,int maxorder,bool brimstone);
int NextPPMdVariantGByte(PPMdModelVariantG *self);

#endif
