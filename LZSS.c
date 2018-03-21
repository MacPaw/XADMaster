/*
 * LZSS.c
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
#include "LZSS.h"

#include <stdlib.h>
#include <string.h>

bool InitializeLZSS(LZSS *self,size_t windowsize)
{
	self->window=malloc(windowsize);
	if(!self->window) return false;

	self->mask=windowsize-1; // Assume windows are power-of-two sized!

	RestartLZSS(self);

	return true;
}

void CleanupLZSS(LZSS *self)
{
	free(self->window);
}

void RestartLZSS(LZSS *self)
{
	memset(self->window,0,LZSSWindowSize(self));
	self->position=0;
}

void CopyBytesFromLZSSWindow(LZSS *self,uint8_t *buffer,int64_t startpos,int length)
{
	size_t windowoffs=LZSSWindowOffsetForPosition(self,startpos);

	if(windowoffs+length<=LZSSWindowSize(self)) // Request fits inside window
	{
		memcpy(buffer,&self->window[windowoffs],length);
	}
	else // Request wraps around window
	{
		size_t firstpart=LZSSWindowSize(self)-windowoffs;
		memcpy(&buffer[0],&self->window[windowoffs],firstpart);
		memcpy(&buffer[firstpart],&self->window[0],length-firstpart);
	}
}
