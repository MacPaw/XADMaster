/*
 * XADFastLZSSHandle.m
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
#import "XADFastLZSSHandle.h"

// TODO: Seeking

@implementation XADFastLZSSHandle

-(id)initWithParentHandle:(CSHandle *)handle windowSize:(int)windowsize
{
	return [self initWithParentHandle:handle length:CSHandleMaxLength windowSize:windowsize];
}

-(id)initWithParentHandle:(CSHandle *)handle length:(off_t)length windowSize:(int)windowsize
{
	if((self=[super initWithParentHandle:handle length:length]))
	{
		InitializeLZSS(&lzss,windowsize);
	}
	return self;
}

-(id)initWithInputBufferForHandle:(CSHandle *)handle windowSize:(int)windowsize
{
	return [self initWithInputBufferForHandle:handle length:CSHandleMaxLength windowSize:windowsize];
}

-(id)initWithInputBufferForHandle:(CSHandle *)handle length:(off_t)length windowSize:(int)windowsize
{
	if((self=[super initWithInputBufferForHandle:handle length:length]))
	{
		InitializeLZSS(&lzss,windowsize);
	}
	return self;
}

-(void)dealloc
{
	CleanupLZSS(&lzss);
	[super dealloc];
}

-(void)resetStream
{
	RestartLZSS(&lzss);
	[self resetLZSSHandle];
}

-(int)streamAtMost:(int)num toBuffer:(void *)buffer
{
	bufferpointer=buffer;
	bufferpos=streampos;
	bufferend=streampos+num;

	XADLZSSFlushToBuffer(self);

	if(bufferpos!=bufferend)
	{
		flushbarrier=LZSSPosition(&lzss)+LZSSWindowSize(&lzss);

		[self expandFromPosition:LZSSPosition(&lzss)];

		XADLZSSFlushToBuffer(self);
	}

	return (int)(bufferpos-streampos);
}

-(void)resetLZSSHandle {}

-(void)expandFromPosition:(off_t)pos {}

-(void)endLZSSHandle { [self endStream]; }

// TODO: remove usage of bufferpos entirely, it's somewhat redundant.
void XADLZSSFlushToBuffer(XADFastLZSSHandle *self)
{
	off_t end=LZSSPosition(&self->lzss);
	if(end>self->bufferend) end=self->bufferend;

	int available=(int)(end-self->bufferpos);
	if(available==0) return;
	//if(available<0) [XADException raiseUnknownException]; // TODO: better error

	CopyBytesFromLZSSWindow(&self->lzss,self->bufferpointer,self->bufferpos,available);

	self->bufferpos+=available;
	self->bufferpointer+=available;
	self->flushbarrier+=available;
}

@end

