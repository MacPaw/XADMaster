/*
 * XADLZSSHandle.h
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
#import "CSByteStreamHandle.h"

#define XADLZSSMatch -1
#define XADLZSSEnd -2


@interface XADLZSSHandle:CSByteStreamHandle
{
	int (*nextliteral_ptr)(id,SEL,int *,int *,off_t);
	@public
	uint8_t *windowbuffer;
	int windowmask,matchlength,matchoffset;
}

-(id)initWithInputBufferForHandle:(CSHandle *)handle windowSize:(int)windowsize;
-(id)initWithInputBufferForHandle:(CSHandle *)handle length:(off_t)length windowSize:(int)windowsize;
-(void)dealloc;

-(void)resetByteStream;
-(uint8_t)produceByteAtOffset:(off_t)pos;

-(void)resetLZSSHandle;
-(int)nextLiteralOrOffset:(int *)offset andLength:(int *)length atPosition:(off_t)pos;

@end

static inline uint8_t XADLZSSByteFromWindow(XADLZSSHandle *self,off_t absolutepos)
{
	return self->windowbuffer[absolutepos&self->windowmask];
}
