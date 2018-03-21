/*
 * LZSS.h
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
#ifndef __LZSS_H__
#define __LZSS_H__

#include <stdint.h>
#include <stdbool.h>
#include <stdlib.h>

typedef struct LZSS
{
	uint8_t *window;
	size_t mask;
	int64_t position;
} LZSS;



bool InitializeLZSS(LZSS *self,size_t windowsize);
void CleanupLZSS(LZSS *self);
void RestartLZSS(LZSS *self);



static inline int64_t LZSSPosition(LZSS *self) { return self->position; }

static inline size_t LZSSWindowMask(LZSS *self) { return self->mask; }

static inline size_t LZSSWindowSize(LZSS *self)  { return self->mask+1; }

static inline uint8_t *LZSSWindowPointer(LZSS *self)  { return self->window; }

static inline size_t LZSSWindowOffsetForPosition(LZSS *self,int64_t pos) { return pos&self->mask; }

static inline uint8_t *LZSSWindowPointerForPosition(LZSS *self,int64_t pos)  { return &self->window[LZSSWindowOffsetForPosition(self,pos)]; }

static inline size_t CurrentLZSSWindowOffset(LZSS *self) { return LZSSWindowOffsetForPosition(self,self->position); }

static inline uint8_t *CurrentLZSSWindowPointer(LZSS *self) { return LZSSWindowPointerForPosition(self,self->position); }

static inline int64_t NextLZSSWindowEdgeAfterPosition(LZSS *self,int64_t pos) { return (pos+LZSSWindowSize(self))&~(int64_t)LZSSWindowMask(self); }

static inline int64_t NextLZSSWindowEdge(LZSS *self) { return NextLZSSWindowEdgeAfterPosition(self,self->position); }




static inline uint8_t GetByteFromLZSSWindow(LZSS *self,int64_t pos)
{
	return *LZSSWindowPointerForPosition(self,pos);
}

void CopyBytesFromLZSSWindow(LZSS *self,uint8_t *buffer,int64_t startpos,int length);




static inline void EmitLZSSLiteral(LZSS *self,uint8_t literal)
{
	*CurrentLZSSWindowPointer(self)=literal;
//	self->window[(self->position)&self->mask]=literal;
	self->position++;
}

static inline void EmitLZSSMatch(LZSS *self,int offset,int length)
{
	int windowoffs=CurrentLZSSWindowOffset(self);

	for(int i=0;i<length;i++)
	{
		self->window[(windowoffs+i)&LZSSWindowMask(self)]=
		self->window[(windowoffs+i-offset)&LZSSWindowMask(self)];
	}

	self->position+=length;
}

#endif

