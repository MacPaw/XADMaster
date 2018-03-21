/*
 * XADZipImplodeHandle.m
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
#import "XADZipImplodeHandle.h"
#import "XADException.h"

@implementation XADZipImplodeHandle

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length
largeDictionary:(BOOL)largedict hasLiterals:(BOOL)hasliterals
{
	if((self=[super initWithInputBufferForHandle:handle length:length windowSize:largedict?8192:4096]))
	{
		if(largedict) offsetbits=7;
		else offsetbits=6;

		literals=hasliterals;

		literalcode=lengthcode=offsetcode=nil;
	}
	return self;
}

-(void)dealloc
{
	[literalcode release];
	[lengthcode release];
	[offsetcode release];
	[super dealloc];
}

-(void)resetLZSSHandle
{
	[literalcode release];
	[lengthcode release];
	[offsetcode release];
	literalcode=lengthcode=offsetcode=nil;

	if(literals) literalcode=[self allocAndParseCodeOfSize:256];
	lengthcode=[self allocAndParseCodeOfSize:64];
	offsetcode=[self allocAndParseCodeOfSize:64];
}

-(XADPrefixCode *)allocAndParseCodeOfSize:(int)size
{
	int numgroups=CSInputNextByte(input)+1;

	int codelengths[size],currcode=0;
	for(int i=0;i<numgroups;i++)
	{
		int val=CSInputNextByte(input);
		int num=(val>>4)+1;
		int length=(val&0x0f)+1;
		while(num--) codelengths[currcode++]=length;
	}
	if(currcode!=size) [XADException raiseDecrunchException];

	return [[XADPrefixCode alloc] initWithLengths:codelengths numberOfSymbols:size maximumLength:16 shortestCodeIsZeros:NO];
}

-(void)expandFromPosition:(off_t)pos;
{
	while(XADLZSSShouldKeepExpanding(self))
	{
		if(CSInputNextBitLE(input))
		{
			if(literals) XADEmitLZSSLiteral(self,CSInputNextSymbolUsingCodeLE(input,literalcode),NULL);
			else XADEmitLZSSLiteral(self,CSInputNextBitStringLE(input,8),NULL);
		}
		else
		{
			int offset=CSInputNextBitStringLE(input,offsetbits);
			offset|=CSInputNextSymbolUsingCodeLE(input,offsetcode)<<offsetbits;
			offset+=1;

			int length=CSInputNextSymbolUsingCodeLE(input,lengthcode)+2;
			if(length==65) length+=CSInputNextBitStringLE(input,8);
			if(literals) length++;

			XADEmitLZSSMatch(self,offset,length,NULL);
		}
	}
}

@end

