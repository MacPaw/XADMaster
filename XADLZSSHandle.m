/*
 * XADLZSSHandle.m
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
#import "XADLZSSHandle.h"

@implementation XADLZSSHandle

/*-(id)initWithName:(NSString *)descname windowSize:(int)windowsize
{
	return [self initWithName:descname length:CSHandleMaxLength windowSize:windowsize];
}

-(id)initWithName:(NSString *)descname length:(off_t)length windowSize:(int)windowsize
{
	if((self=[super initWithName:descname length:length]))
	{
		nextliteral_ptr=(int (*)(id,SEL,int *,int *,off_t))
		[self methodForSelector:@selector(nextLiteralOrOffset:andLength:atPosition:)];

		windowbuffer=malloc(windowsize);
		windowmask=windowsize-1; // Assumes windows are always power-of-two sized!
	}
	return self;
}*/

-(id)initWithInputBufferForHandle:(CSHandle *)handle windowSize:(int)windowsize
{
	return [self initWithInputBufferForHandle:handle length:CSHandleMaxLength windowSize:windowsize];
}

-(id)initWithInputBufferForHandle:(CSHandle *)handle length:(off_t)length windowSize:(int)windowsize
{
	if((self=[super initWithInputBufferForHandle:handle length:length]))
	{
		nextliteral_ptr=(int (*)(id,SEL,int *,int *,off_t))
		[self methodForSelector:@selector(nextLiteralOrOffset:andLength:atPosition:)];

		windowbuffer=malloc(windowsize);
		windowmask=windowsize-1; // Assumes windows are always power-of-two sized!
	}
	return self;
}

-(void)dealloc
{
	free(windowbuffer);
	[super dealloc];
}

-(void)resetByteStream
{
	matchlength=0;
	matchoffset=0;
	memset(windowbuffer,0,windowmask+1);

	[self resetLZSSHandle];
}

-(uint8_t)produceByteAtOffset:(off_t)pos
{
	if(!matchlength)
	{
		int offset,length;
		int val=nextliteral_ptr(self,@selector(nextLiteralOrOffset:andLength:atPosition:),&offset,&length,pos);

		if(val>=0)
		{
			windowbuffer[pos&windowmask]=val;
			return val;
		}
		else if(val==XADLZSSEnd)
		{
			CSByteStreamEOF(self);
		}
		else
		{
			matchlength=length;
			matchoffset=(int)(pos-offset);
		}
	}

	matchlength--;

	uint8_t byte=windowbuffer[matchoffset++&windowmask];

	windowbuffer[pos&windowmask]=byte;

	return byte;
}

-(void)resetLZSSHandle {}

-(int)nextLiteralOrOffset:(int *)offset andLength:(int *)length atPosition:(off_t)pos { return XADLZSSEnd; }

@end
