/*
 * XADBlockHandle.m
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
#import "XADBlockHandle.h"

@implementation XADBlockHandle

-(id)initWithHandle:(CSHandle *)handle blockSize:(int)size
{
	if((self=[super initWithParentHandle:handle]))
	{
		currpos=0;
		length=CSHandleMaxLength;
		numblocks=0;
		blocksize=size;
		blockoffsets=NULL;
	}
	return self;
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)maxlength blockSize:(int)size
{
	if((self=[super initWithParentHandle:handle]))
	{
		currpos=0;
		length=maxlength;
		numblocks=0;
		blocksize=size;
		blockoffsets=NULL;
	}
	return self;
}

-(void)dealloc
{
	free(blockoffsets);
	[super dealloc];
}


-(void)setBlockChain:(uint32_t *)blocktable numberOfBlocks:(int)totalblocks
firstBlock:(uint32_t)first headerSize:(off_t)headersize
{
	numblocks=0;
	uint32_t block=first;
	while(block<totalblocks)
	{
		block=blocktable[block];
		numblocks++;
	}

	free(blockoffsets);
	if(numblocks==0) blockoffsets=NULL;
	else blockoffsets=malloc(numblocks*sizeof(off_t));

	block=first;
	for(int i=0;i<numblocks;i++)
	{
		blockoffsets[i]=headersize+block*blocksize;
		block=blocktable[block];
	}
}

-(off_t)fileSize
{
	if(length<numblocks*blocksize) return length;
	return numblocks*blocksize;
}

-(off_t)offsetInFile
{
	return currpos;
}

-(BOOL)atEndOfFile
{
	if(currpos==numblocks*blocksize) return YES;
	if(currpos==length) return YES;
	return NO;
}

-(void)seekToFileOffset:(off_t)offs
{
	if(offs<0) [self _raiseEOF];
	if(offs>numblocks*blocksize) [self _raiseEOF];
	if(offs>length) [self _raiseEOF];

	int block=(int)((offs-1)/blocksize);

	[parent seekToFileOffset:blockoffsets[block]+offs-block*blocksize];
	currpos=offs;
}

-(void)seekToEndOfFile
{
	if(length!=CSHandleMaxLength) [self seekToFileOffset:length];
	else [self seekToFileOffset:numblocks*blocksize];
}

-(int)readAtMost:(int)num toBuffer:(void *)buffer
{
	uint8_t *bytebuffer=(uint8_t *)buffer;
	int total=0;

	if(currpos+num>length) num=(int)(length-currpos);

	while(total<num)
	{
		int blockpos=currpos%blocksize;
		if(blockpos==0)
		{
			int block=(int)(currpos/blocksize);
			if(block==numblocks) return total;
			[parent seekToFileOffset:blockoffsets[block]];
		}

		int numbytes=num-total;
		if(numbytes>blocksize-blockpos) numbytes=blocksize-blockpos;

		int actual=[parent readAtMost:numbytes toBuffer:&bytebuffer[total]];
		if(actual==0) return total;

		total+=actual;
		currpos+=actual;
	}

	return total;
}

@end
