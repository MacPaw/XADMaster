/*
 * LZW.c
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
#include "LZW.h"
#include <stdlib.h>

LZW *AllocLZW(int maxsymbols,int reservedsymbols)
{
	LZW *self=(LZW *)malloc(sizeof(LZW)+sizeof(LZWTreeNode)*maxsymbols);
	if(!self) return NULL;

	if(maxsymbols<256+reservedsymbols) return NULL;

	self->maxsymbols=maxsymbols;
	self->reservedsymbols=reservedsymbols;

	self->buffer=NULL;
	self->buffersize=0;

	for(int i=0;i<256;i++)
	{
		self->nodes[i].chr=i;
		self->nodes[i].parent=-1;
		self->nodes[i].inuse=1;
	}

	ClearLZWTable(self);

	return self;
}

void FreeLZW(LZW *self)
{
	if(self)
	{
		free(self->buffer);
		free(self);
	}
}

void ClearLZWTable(LZW *self)
{
	self->freesymbols=256+self->reservedsymbols;
	for (int i=self->freesymbols; i<self->maxsymbols; i++)
	{
		self->nodes[i].parent=i+1;
		self->nodes[i].inuse=0;
	}
	self->nodes[self->maxsymbols-1].parent=-1;
	self->prevsymbol=-1;
	self->symbolsize=9; // TODO: technically this depends on reservedsymbols
}

// Partial clearing as used by the ZIP Shrink algorithm
void ClearLZWLeaves(LZW *self)
{
	int firstsymbol=256+self->reservedsymbols;

	// Mark the parents of any nodes currently in use
	// self->nodes[x].inuse will be 2 for any such parents; these nodes will
	// not be cleared
	for (int i=firstsymbol; i<self->maxsymbols; i++)
	{
		if (self->nodes[i].inuse)
		{
			int parent=self->nodes[i].parent;
			if (parent>=firstsymbol) self->nodes[parent].inuse=2;
		}
	}
	// Mark leaf nodes as free and rebuild the free list
	self->freesymbols=-1;
	for (int i=self->maxsymbols-1; i>=firstsymbol; i--)
	{
		if (self->nodes[i].inuse==2)
		{
			// This node is not to be cleared
			self->nodes[i].inuse=1;
		}
		else
		{
			// This node is to be cleared, or was already free
			self->nodes[i].inuse=0;
			self->nodes[i].parent=self->freesymbols;
			self->freesymbols=i;
		}
	}
	// self->prevsymbol is left alone
}

static uint8_t FindFirstByte(LZW *self,int symbol)
{
	while (1)
	{
		if (!self->nodes[symbol].inuse && symbol!=self->prevsymbol)
			// This can happen after ClearLZWLeaves
			// Check for symbol!-self->prevsymbol avoids infinite loop
			symbol=self->prevsymbol;
		else if (self->nodes[symbol].parent>=0)
			symbol=self->nodes[symbol].parent;
		else
			break;
	}
	return self->nodes[symbol].chr;
}

int NextLZWSymbol(LZW *self,int symbol)
{
	if(self->prevsymbol<0)
	{
		if(symbol>=self->maxsymbols) return LZWInvalidCodeError;
		if(!self->nodes[symbol].inuse) return LZWInvalidCodeError;
		self->prevsymbol=symbol;

		return LZWNoError;
	}

	int postfixbyte;
	if(symbol<self->maxsymbols && self->nodes[symbol].inuse) postfixbyte=FindFirstByte(self,symbol);
	else if(symbol==self->freesymbols) postfixbyte=FindFirstByte(self,self->prevsymbol);
	else return LZWInvalidCodeError;

	int parent=self->prevsymbol;
	self->prevsymbol=symbol;

	if(!LZWSymbolListFull(self))
	{
		int nextsymbol=self->nodes[self->freesymbols].parent;
		self->nodes[self->freesymbols].parent=parent;
		self->nodes[self->freesymbols].chr=postfixbyte;
		self->nodes[self->freesymbols].inuse=1;
		self->freesymbols=nextsymbol;

		if(!LZWSymbolListFull(self))
		if((self->freesymbols&(self->freesymbols-1))==0) self->symbolsize++;

		return LZWNoError;
	}
	else
	{
		return LZWTooManyCodesError;
	}
}

int ReplaceLZWSymbol(LZW *self,int oldsymbol,int symbol)
{
	if(symbol>=self->maxsymbols || !self->nodes[symbol].inuse) return LZWInvalidCodeError;

	self->nodes[oldsymbol].parent=self->prevsymbol;
	self->nodes[oldsymbol].chr=FindFirstByte(self,symbol);
	self->nodes[oldsymbol].inuse=1;

	self->prevsymbol=symbol;

	return LZWNoError;
}

int LZWOutputLength(LZW *self)
{
	int symbol=self->prevsymbol;
	int n=0;

	while(symbol>=0)
	{
		symbol=self->nodes[symbol].parent;
		n++;
	}

	return n;
}

int LZWOutputToBuffer(LZW *self,uint8_t *buffer)
{
	int symbol=self->prevsymbol;
	int n=LZWOutputLength(self);
	buffer+=n;

	while(symbol>=0)
	{
		*--buffer=self->nodes[symbol].chr;
		symbol=self->nodes[symbol].parent;
	}

	return n;
}

int LZWReverseOutputToBuffer(LZW *self,uint8_t *buffer)
{
	int symbol=self->prevsymbol;
	int n=0;

	while(symbol>=0)
	{
		*buffer++=self->nodes[symbol].chr;
		symbol=self->nodes[symbol].parent;
		n++;
	}

	return n;
}

int LZWOutputToInternalBuffer(LZW *self)
{
	int symbol=self->prevsymbol;
	int n=LZWOutputLength(self);

	if(n>self->buffersize)
	{
		free(self->buffer);
		self->buffersize+=1024;
		self->buffer=malloc(self->buffersize);
	}

	uint8_t *buffer=self->buffer+n;
	while(symbol>=0)
	{
		*--buffer=self->nodes[symbol].chr;
		symbol=self->nodes[symbol].parent;
	}

	return n;
}
