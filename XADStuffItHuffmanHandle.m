/*
 * XADStuffItHuffmanHandle.m
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
#import "XADStuffItHuffmanHandle.h"

@implementation XADStuffItHuffmanHandle

-(id)initWithHandle:(CSHandle *)handle
{
	return [self initWithHandle:handle length:CSHandleMaxLength];
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length
{
	if((self=[super initWithInputBufferForHandle:handle length:length]))
	{
		code=nil;
	}
	return self;
}

-(void)dealloc
{
	[code release];
	[super dealloc];
}

-(void)resetByteStream
{
	[code release];
	code=[XADPrefixCode new];

	[code startBuildingTree];
	[self parseTree];
}

-(void)parseTree
{
	if(CSInputNextBit(input)==1)
	{
		[code makeLeafWithValue:CSInputNextBitString(input,8)];
	}
	else
	{
		[code startZeroBranch];
		[self parseTree];
		[code startOneBranch];
		[self parseTree];
		[code finishBranches];
	}
}

-(uint8_t)produceByteAtOffset:(off_t)pos
{
	return CSInputNextSymbolUsingCode(input,code);
}

@end
