/*
 * XADDiskDoublerMethod2Handle.m
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
#import "XADDiskDoublerMethod2Handle.h"
#import "XADException.h"

@implementation XADDiskDoublerMethod2Handle

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length numberOfTrees:(int)num
{
	if((self=[super initWithInputBufferForHandle:handle length:length]))
	{
		numtrees=num;
	}
	return self;
}

-(void)resetByteStream
{
	for(int i=0;i<numtrees;i++)
	{
		for(int j=0;j<256;j++)
		{
			trees[i].parents[2*j]=j;
			trees[i].parents[2*j+1]=j;
			trees[i].leftchildren[j]=j*2;
			trees[i].rightchildren[j]=j*2+1;
		}
	}

	currtree=0;
}

-(uint8_t)produceByteAtOffset:(off_t)pos
{
	int node=1;
	for(;;)
	{
		int bit=CSInputNextBit(input);

		if(bit==1) node=trees[currtree].rightchildren[node];
		else node=trees[currtree].leftchildren[node];

		if(node>=0x100)
		{
			int byte=node-0x100;

			[self updateStateForByte:byte];

			return byte;
		}
	}
}

-(void)updateStateForByte:(int)byte
{
	uint8_t *parents=trees[currtree].parents;
	uint16_t *leftchildren=trees[currtree].leftchildren;
	uint16_t *rightchildren=trees[currtree].rightchildren;

	int node=byte+0x100;
	for(;;)
	{
		int parentnode=parents[node];
		if(parentnode==1) break;

		int grandparent=parents[parentnode];

		int uncle=leftchildren[grandparent];
		if(uncle==parentnode)
		{
			uncle=rightchildren[grandparent];
			rightchildren[grandparent]=node;
		}
		else
		{
			leftchildren[grandparent]=node;
		}

		if(leftchildren[parentnode]!=node) rightchildren[parentnode]=uncle;
		else leftchildren[parentnode]=uncle;

		parents[node]=grandparent;
		parents[uncle]=parentnode;

		node=grandparent;
		if(node==1) break;
	}

	currtree=byte%numtrees;
}

@end
