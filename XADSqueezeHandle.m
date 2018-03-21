/*
 * XADSqueezeHandle.m
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
#import "XADSqueezeHandle.h"
#import "XADException.h"

@implementation XADSqueezeHandle

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


static void BuildCodeFromTree(XADPrefixCode *code,int *tree,int node,int numnodes,int depth)
{
	if(depth>64) [XADException raiseDecrunchException];

	if(node<0)
	{
		[code makeLeafWithValue:-(node+1)];
	}
	else if(2*node+1<numnodes)
	{
		[code startZeroBranch];
		BuildCodeFromTree(code,tree,tree[2*node],numnodes,depth+1);
		[code startOneBranch];
		BuildCodeFromTree(code,tree,tree[2*node+1],numnodes,depth+1);
		[code finishBranches];
	}
	else
	{
		[XADException raiseDecrunchException];
	}
}

-(void)resetByteStream
{
	int numnodes=CSInputNextUInt16LE(input)*2;
	if(numnodes>=257*2) [XADException raiseDecrunchException];

	int nodes[numnodes];
	nodes[0]=nodes[1]=-(256+1);

	for(int i=0;i<numnodes;i++) nodes[i]=CSInputNextInt16LE(input);

	[code release];
	code=[XADPrefixCode new];

	[code startBuildingTree];
	BuildCodeFromTree(code,nodes,0,numnodes,0);
}

-(uint8_t)produceByteAtOffset:(off_t)pos
{
	int symbol=CSInputNextSymbolUsingCodeLE(input,code);
	if(symbol==256) CSByteStreamEOF(self);
	return symbol;
}

@end
