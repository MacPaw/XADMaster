/*
 * XADStuffItXBlockHandle.m
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
#import "XADStuffItXBlockHandle.h"
#import "StuffItXUtilities.h"
#import "XADException.h"

@implementation XADStuffItXBlockHandle

-(id)initWithHandle:(CSHandle *)handle
{
	if((self=[super initWithParentHandle:handle]))
	{
		startoffs=[parent offsetInFile];
		buffer=NULL;
		currsize=0;
	}
	return self;
}

-(void)dealloc
{
	free(buffer);
	[super dealloc];
}

-(void)resetBlockStream
{
	[parent seekToFileOffset:startoffs];
}

-(int)produceBlockAtOffset:(off_t)pos
{
	unsigned int size=(unsigned int)ReadSitxP2(parent);
	if(!size) return -1;

	if(size>currsize)
	{
		free(buffer);
		buffer=malloc(size);
		if(!buffer) [XADException raiseOutOfMemoryException];
		currsize=size;
		[self setBlockPointer:buffer];
	}

	return [parent readAtMost:size toBuffer:buffer];
}

@end
