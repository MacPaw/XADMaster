/*
 * CSInputBuffer.h
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
#import <Foundation/Foundation.h>
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wquoted-include-in-framework-header"
#import "CSHandle.h"
#pragma clang diagnostic pop

typedef struct CSInputBuffer
{
	CSHandle *parent;
	off_t startoffs;
	BOOL eof;

	uint8_t *buffer;
	unsigned int bufsize,bufbytes,currbyte;

	uint32_t bits;
	unsigned int numbits;
} CSInputBuffer;



// Allocation and management

XADEXPORT CSInputBuffer *CSInputBufferAlloc(CSHandle *parent,int size);
XADEXPORT CSInputBuffer *CSInputBufferAllocWithBuffer(const uint8_t *buffer,int length,off_t startoffs);
XADEXPORT CSInputBuffer *CSInputBufferAllocEmpty(void);
XADEXPORT void CSInputBufferFree(CSInputBuffer *self);

XADEXPORT void CSInputSetMemoryBuffer(CSInputBuffer *self,uint8_t *buffer,int length,off_t startoffs);

static inline CSHandle *CSInputHandle(CSInputBuffer *self)
{
	return self->parent;
}



// Buffer and file positioning

XADEXPORT void CSInputRestart(CSInputBuffer *self);
XADEXPORT void CSInputFlush(CSInputBuffer *self);

XADEXPORT void CSInputSynchronizeFileOffset(CSInputBuffer *self);
XADEXPORT void CSInputSeekToFileOffset(CSInputBuffer *self,off_t offset);
XADEXPORT void CSInputSeekToBufferOffset(CSInputBuffer *self,off_t offset);
XADEXPORT void CSInputSetStartOffset(CSInputBuffer *self,off_t offset);
XADEXPORT off_t CSInputBufferOffset(CSInputBuffer *self);
XADEXPORT off_t CSInputFileOffset(CSInputBuffer *self);
XADEXPORT off_t CSInputBufferBitOffset(CSInputBuffer *self);

XADEXPORT void _CSInputFillBuffer(CSInputBuffer *self);




// Byte reading

#define CSInputBufferLookAhead 4

static inline void _CSInputBufferRaiseEOF(CSInputBuffer *self)
{
	if(self->parent) [self->parent _raiseEOF];
	else [NSException raise:CSEndOfFileException
	format:@"Attempted to read past the end of memory buffer."];
}

static inline int _CSInputBytesLeftInBuffer(CSInputBuffer *self)
{
	return self->bufbytes-self->currbyte;
}

static inline void _CSInputCheckAndFillBuffer(CSInputBuffer *self)
{
	if(!self->eof&&_CSInputBytesLeftInBuffer(self)<=CSInputBufferLookAhead) _CSInputFillBuffer(self);
}

static inline void CSInputSkipBytes(CSInputBuffer *self,int num)
{
	self->currbyte+=num;
}

static inline int _CSInputPeekByteWithoutEOF(CSInputBuffer *self,int offs)
{
	return self->buffer[self->currbyte+offs];
}

static inline int CSInputPeekByte(CSInputBuffer *self,int offs)
{
	_CSInputCheckAndFillBuffer(self);
	if(offs>=_CSInputBytesLeftInBuffer(self)) _CSInputBufferRaiseEOF(self);
	return _CSInputPeekByteWithoutEOF(self,offs);
}

static inline int CSInputNextByte(CSInputBuffer *self)
{
	int byte=CSInputPeekByte(self,0);
	CSInputSkipBytes(self,1);
	return byte;
}

static inline BOOL CSInputAtEOF(CSInputBuffer *self)
{
	_CSInputCheckAndFillBuffer(self);
	return _CSInputBytesLeftInBuffer(self)<=0;
}




// Bitstream reading

XADEXPORT void _CSInputFillBits(CSInputBuffer *self);
XADEXPORT void _CSInputFillBitsLE(CSInputBuffer *self);

XADEXPORT unsigned int CSInputNextBit(CSInputBuffer *self);
XADEXPORT unsigned int CSInputNextBitLE(CSInputBuffer *self);
XADEXPORT unsigned int CSInputNextBitString(CSInputBuffer *self,int numbits);
XADEXPORT unsigned int CSInputNextBitStringLE(CSInputBuffer *self,int numbits);
XADEXPORT unsigned int CSInputNextLongBitString(CSInputBuffer *self,int numbits);
XADEXPORT unsigned int CSInputNextLongBitStringLE(CSInputBuffer *self,int numbits);

XADEXPORT void CSInputSkipBits(CSInputBuffer *self,int numbits);
XADEXPORT void CSInputSkipBitsLE(CSInputBuffer *self,int numbits);
XADEXPORT BOOL CSInputOnByteBoundary(CSInputBuffer *self);
XADEXPORT void CSInputSkipToByteBoundary(CSInputBuffer *self);
XADEXPORT void CSInputSkipTo16BitBoundary(CSInputBuffer *self);

static inline unsigned int CSInputBitsLeftInBuffer(CSInputBuffer *self)
{
	_CSInputCheckAndFillBuffer(self);
	return _CSInputBytesLeftInBuffer(self)*8+(self->numbits&7);
}

static inline void _CSInputCheckAndFillBits(CSInputBuffer *self,int numbits)
{
	if(numbits>self->numbits) _CSInputFillBits(self);
}

static inline void _CSInputCheckAndFillBitsLE(CSInputBuffer *self,int numbits)
{
	if(numbits>self->numbits) _CSInputFillBitsLE(self);
}

static inline unsigned int CSInputPeekBitString(CSInputBuffer *self,int numbits)
{
	if(numbits==0) return 0;
	_CSInputCheckAndFillBits(self,numbits);
	return self->bits>>(32-numbits);
}

static inline unsigned int CSInputPeekBitStringLE(CSInputBuffer *self,int numbits)
{
	if(numbits==0) return 0;
	_CSInputCheckAndFillBitsLE(self,numbits);
	return self->bits&((1<<numbits)-1);
}

static inline void CSInputSkipPeekedBits(CSInputBuffer *self,int numbits)
{
	int numbytes=(numbits-(self->numbits&7)+7)>>3;
	CSInputSkipBytes(self,numbytes);

	if(_CSInputBytesLeftInBuffer(self)<0) _CSInputBufferRaiseEOF(self);

	self->bits<<=numbits;
	self->numbits-=numbits;
}

static inline void CSInputSkipPeekedBitsLE(CSInputBuffer *self,int numbits)
{
	int numbytes=(numbits-(self->numbits&7)+7)>>3;
	CSInputSkipBytes(self,numbytes);

	if(_CSInputBytesLeftInBuffer(self)<0) _CSInputBufferRaiseEOF(self);

	self->bits>>=numbits;
	self->numbits-=numbits;
}




// Multibyte reading

#define CSInputNextValueImpl(type,name,conv) \
static inline type name(CSInputBuffer *self) \
{ \
	_CSInputCheckAndFillBuffer(self); \
	type val=conv(self->buffer+self->currbyte); \
	CSInputSkipBytes(self,sizeof(type)); \
	return val; \
}

XADEXPORT CSInputNextValueImpl(int16_t,CSInputNextInt16LE,CSInt16LE)
XADEXPORT CSInputNextValueImpl(int32_t,CSInputNextInt32LE,CSInt32LE)
XADEXPORT CSInputNextValueImpl(uint16_t,CSInputNextUInt16LE,CSUInt16LE)
XADEXPORT CSInputNextValueImpl(uint32_t,CSInputNextUInt32LE,CSUInt32LE)
XADEXPORT CSInputNextValueImpl(int16_t,CSInputNextInt16BE,CSInt16BE)
XADEXPORT CSInputNextValueImpl(int32_t,CSInputNextInt32BE,CSInt32BE)
XADEXPORT CSInputNextValueImpl(uint16_t,CSInputNextUInt16BE,CSUInt16BE)
XADEXPORT CSInputNextValueImpl(uint32_t,CSInputNextUInt32BE,CSUInt32BE)




