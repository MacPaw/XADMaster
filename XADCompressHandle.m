/*
 * XADCompressHandle.m
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
#import "XADCompressHandle.h"
#import "XADException.h"

@implementation XADCompressHandle

-(id)initWithHandle:(CSHandle *)handle flags:(int)compressflags
{
	return [self initWithHandle:handle length:CSHandleMaxLength flags:compressflags];
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length flags:(int)compressflags
{
	if((self=[super initWithInputBufferForHandle:handle length:length]))
	{
		blockmode=(compressflags&0x80)!=0;

		int maxsymbols=1<<(compressflags&0x1f);
		if(maxsymbols<=256) [XADException raiseDecrunchException];

		lzw=AllocLZW(maxsymbols,blockmode?1:0);
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
	symbolcounter=0;
	buffer=bufferend=NULL;
}

-(uint8_t)produceByteAtOffset:(off_t)pos
{
	if(buffer>=bufferend)
	{
		int symbol;
		for(;;)
		{
			if(CSInputAtEOF(input)) CSByteStreamEOF(self);

			symbol=CSInputNextBitStringLE(input,LZWSuggestedSymbolSize(lzw));
			symbolcounter++;
			if(symbol==256&&blockmode)
			{
				// Skip garbage data after a clear. God damn, this is dumb.
				int symbolsize=LZWSuggestedSymbolSize(lzw);
				if(symbolcounter%8) CSInputSkipBitsLE(input,symbolsize*(8-symbolcounter%8));
				ClearLZWTable(lzw);
				symbolcounter=0;
			}
			else break;
		}

		if(NextLZWSymbol(lzw,symbol)==LZWInvalidCodeError) [XADException raiseDecrunchException];

		int n=LZWOutputToInternalBuffer(lzw);
		buffer=LZWInternalBuffer(lzw);
		bufferend=buffer+n;
	}

	return *buffer++;
}

@end
