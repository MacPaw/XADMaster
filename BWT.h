/*
 * BWT.h
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
#ifndef __BWT_H__
#define __BWT_H__

#include <stdint.h>
#include <stdbool.h>

void CalculateInverseBWT(uint32_t *transform,uint8_t *block,int blocklen);
void UnsortBWT(uint8_t *dest,uint8_t *src,int blocklen,int firstindex,uint32_t *transformbuf);

bool UnsortST4(uint8_t *dest,uint8_t *src,int blocklen,int firstindex,uint32_t *transformbuf);

typedef struct MTFState
{
	int table[256];
} MTFState;

void ResetMTFDecoder(MTFState *self);
int DecodeMTF(MTFState *self,int symbol);
void DecodeMTFBlock(uint8_t *block,int blocklen);
void DecodeM1FFNBlock(uint8_t *block,int blocklen,int order);

#endif
