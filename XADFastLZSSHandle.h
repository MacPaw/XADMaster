/*
 * XADFastLZSSHandle.h
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
#import "CSStreamHandle.h"
#import "LZSS.h"
#import "XADException.h"

@interface XADFastLZSSHandle:CSStreamHandle
{
	@public
	LZSS lzss;
	off_t flushbarrier;

	off_t bufferpos,bufferend;
	uint8_t *bufferpointer;
}

-(id)initWithParentHandle:(CSHandle *)handle windowSize:(int)windowsize;
-(id)initWithParentHandle:(CSHandle *)handle length:(off_t)length windowSize:(int)windowsize;
-(id)initWithInputBufferForHandle:(CSHandle *)handle windowSize:(int)windowsize;
-(id)initWithInputBufferForHandle:(CSHandle *)handle length:(off_t)length windowSize:(int)windowsize;
-(void)dealloc;

-(void)resetStream;
-(int)streamAtMost:(int)num toBuffer:(void *)buffer;

-(void)resetLZSSHandle;
-(void)expandFromPosition:(off_t)pos;

-(void)endLZSSHandle;

@end



void XADLZSSFlushToBuffer(XADFastLZSSHandle *self);

static inline BOOL XADLZSSShouldKeepExpanding(XADFastLZSSHandle *self)
{
	return LZSSPosition(&self->lzss)<self->bufferend;
}

static inline void XADEmitLZSSLiteral(XADFastLZSSHandle *self,uint8_t byte,off_t *pos)
{
	if(LZSSPosition(&self->lzss)==self->flushbarrier) XADLZSSFlushToBuffer(self);

	EmitLZSSLiteral(&self->lzss,byte);
	if(pos) *pos=LZSSPosition(&self->lzss);
}

static inline void XADEmitLZSSMatch(XADFastLZSSHandle *self,int offset,int length,off_t *pos)
{
	// You can not emit more than the window size, or data would get lost. If you need to do this,
	// you need to divide the match into smaller parts so you can call ShouldKeepExpanding in between and
	// exit if needed. See XADStacLZSHandle for an example.
	if(length>LZSSWindowSize(&self->lzss)) [XADException raiseDecrunchException];

	if(LZSSPosition(&self->lzss)+length>self->flushbarrier) XADLZSSFlushToBuffer(self);

	EmitLZSSMatch(&self->lzss,offset,length);
	if(pos) *pos=LZSSPosition(&self->lzss);
}

/*static inline uint8_t XADLZSSByteFromWindow2(XADFastLZSSHandle *self,off_t absolutepos)
{
	return self->windowbuffer[absolutepos&self->windowmask];
}*/
