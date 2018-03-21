/*
 * XADZipShrinkHandle.m
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
#import "XADZipShrinkHandle.h"
#import "XADException.h"


@implementation XADZipShrinkHandle

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length
{
	if((self=[super initWithInputBufferForHandle:handle length:length]))
	{
		lzw=AllocLZW(8192,1);
	}
	return self;
}

-(void)dealloc
{
	FreeLZW(lzw);
	[super dealloc];
}

-(void)resetByteStream
{
	ClearLZWTable(lzw);
	symbolsize=9;
	currbyte=0;
}

-(uint8_t)produceByteAtOffset:(off_t)pos
{
	if(!currbyte)
	{
		int symbol;
		for(;;)
		{
			symbol=CSInputNextBitStringLE(input,symbolsize);
			if(symbol==256)
			{
				int next=CSInputNextBitStringLE(input,symbolsize);
				if(next==1)
				{
					symbolsize++;
					if(symbolsize>13) [XADException raiseDecrunchException];
				}
				else if(next==2) ClearLZWTable(lzw);
			}
			else break;
		}

		if(NextLZWSymbol(lzw,symbol)!=LZWNoError) [XADException raiseDecrunchException];
		currbyte=LZWReverseOutputToBuffer(lzw,buffer);
	}

	return buffer[--currbyte];
}

@end
