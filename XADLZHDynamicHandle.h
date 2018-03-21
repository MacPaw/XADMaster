/*
 * XADLZHDynamicHandle.h
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
#import "XADPrefixCode.h"

typedef struct XADLZHDynamicNode XADLZHDynamicNode;

struct XADLZHDynamicNode
{
	XADLZHDynamicNode *parent,*leftchild,*rightchild;
	int index,freq,value;
};

@interface XADLZHDynamicHandle:XADLZSSHandle
{
	XADPrefixCode *distancecode;
	XADLZHDynamicNode *nodes[314*2-1],nodestorage[314*2-1];
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length;
-(void)dealloc;

-(void)resetLZSSHandle;
-(int)nextLiteralOrOffset:(int *)offset andLength:(int *)length atPosition:(off_t)pos;

-(void)updateNode:(XADLZHDynamicNode *)node;
-(void)rearrangeNode:(XADLZHDynamicNode *)node;
-(void)reconstructTree;

@end
