/*
 * XADDiskDoublerADnHandle.m
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
#import "XADDiskDoublerADnHandle.h"
#import "XADException.h"

static void CopyBytesWithRepeat(uint8_t *dest,uint8_t *src,int length)
{
	for(int i=0;i<length;i++) dest[i]=src[i];
}

@implementation XADDiskDoublerADnHandle

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length
{
	return [super initWithInputBufferForHandle:handle length:length];
}

-(int)produceBlockAtOffset:(off_t)pos
{
	uint8_t headxor=0;

	int compsize=CSInputNextUInt16BE(input);
	//if(compsize>0x2000) [XADException raiseIllegalDataException];
	headxor^=compsize^(compsize>>8);

	int uncompsize=CSInputNextUInt16BE(input);
	if(uncompsize>0x2000) [XADException raiseIllegalDataException];
	headxor^=uncompsize^(uncompsize>>8);

	for(int i=0;i<4;i++) headxor^=CSInputNextByte(input);

	int datacorrectxor=CSInputNextByte(input);
	headxor^=datacorrectxor;

	int flags=CSInputNextByte(input);
	headxor^=flags;

	headxor^=CSInputNextByte(input);

	int headcorrectxor=CSInputNextByte(input);
	if(headxor!=headcorrectxor) [XADException raiseIllegalDataException];

	off_t nextblock=CSInputBufferOffset(input)+compsize;

	if(flags&1)
	{
		// Uncompressed block
		for(int i=0;i<uncompsize;i++) outbuffer[i]=CSInputNextByte(input);
	}
	else
	{
		int currpos=0;
		while(currpos<uncompsize)
		{
			int ismatch=CSInputNextBit(input);

			if(!ismatch) outbuffer[currpos++]=CSInputNextBitString(input,8);
			else
			{
				int isfar=CSInputNextBit(input);
				int offset=CSInputNextBitString(input,isfar?12:8);
				if(offset>currpos) [XADException raiseIllegalDataException];

				int length;
				if(CSInputNextBit(input)==0) length=2;
				else
				{
					if(CSInputNextBit(input)==0)
					{
						if(CSInputNextBit(input)==0) length=3;
						else length=4;
					}
					else length=CSInputNextBitString(input,4)+5;
				}

				if(currpos+length>uncompsize) length=uncompsize-currpos;
				if(length>offset) [XADException raiseIllegalDataException];

				CopyBytesWithRepeat(&outbuffer[currpos],&outbuffer[currpos-offset],length);
				currpos+=length;
			}
		}
	}

	CSInputSeekToBufferOffset(input,nextblock);

	[self setBlockPointer:outbuffer];
	return uncompsize;
}

@end
