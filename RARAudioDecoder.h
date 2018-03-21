/*
 * RARAudioDecoder.h
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
#ifndef __RARAUDIODECODER_H__
#define __RARAUDIODECODER_H__

typedef struct RAR20AudioState
{
	int weight1,weight2,weight3,weight4,weight5;
	int delta1,delta2,delta3,delta4;
	int lastdelta;
	int error[11];
	int count;
	int lastbyte;
} RAR20AudioState;

typedef struct RAR30AudioState
{
	int weight1,weight2,weight3,weight4,weight5;
	int delta1,delta2,delta3,delta4;
	int lastdelta;
	int error[7];
	int count;
	int lastbyte;
} RAR30AudioState;

int DecodeRAR20Audio(RAR20AudioState *state,int *channeldelta,int delta);
int DecodeRAR30Audio(RAR30AudioState *state,int delta);

#endif
