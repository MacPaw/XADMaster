/*
 * LZWHandle.m
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
#import "LZWHandle.h"

NSString *LZWInvalidCodeException=@"LZWInvalidCodeException";


@implementation LZWHandle

-(id)initWithHandle:(CSHandle *)handle earlyChange:(BOOL)earlychange
{
	if(self=[super initWithInputBufferForHandle:handle])
	{
		early=earlychange;
		lzw=AllocLZW(4096+1,2);
	}
	return self;
}

-(void)dealloc
{
	FreeLZW(lzw);
	[super dealloc];
}

-(void)clearTable
{
	ClearLZWTable(lzw);
	symbolsize=9;
	currbyte=0;
}

-(void)resetByteStream
{
	[self clearTable];
}

-(uint8_t)produceByteAtOffset:(off_t)pos
{
	if(!currbyte)
	{
		int symbol;
		for(;;)
		{
			symbol=CSInputNextBitString(input,symbolsize);
			if(symbol==256) [self clearTable];
			else break;
		}

		if(symbol==257) CSByteStreamEOF(self);

		int err=NextLZWSymbol(lzw,symbol);
		if(err!=LZWNoError) [NSException raise:LZWInvalidCodeException format:@"Invalid code in LZW stream (error code %d)",err];
		currbyte=LZWReverseOutputToBuffer(lzw,buffer);

		int offs=early?1:0;
		int numsymbols=LZWSymbolCount(lzw);
		if(numsymbols==512-offs) symbolsize=10;
		else if(numsymbols==1024-offs) symbolsize=11;
		else if(numsymbols==2048-offs) symbolsize=12;
	}

	return buffer[--currbyte];
}

@end

