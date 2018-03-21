/*
 * StuffItXUtilities.m
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
#import "StuffItXUtilities.h"
#import "XADException.h"

uint64_t ReadSitxP2(CSHandle *fh)
{
	int n=1;
	while([fh readBitsLE:1]==1 && n<64) n++;
	if(n>=64) [XADException raiseDecrunchException];

	uint64_t value=0;
	uint64_t bit=1;

	while(n)
	{
		if([fh readBitsLE:1]==1)
		{
			n--;
			value|=bit;
		}
		bit<<=1;
	}
	return value-1;
}

uint32_t ReadSitxUInt32(CSHandle *fh)
{
	uint32_t val=0;
	for(int i=0;i<sizeof(val);i++) val=(val<<8)|[fh readBitsLE:8];
	return val;
}

uint64_t ReadSitxUInt64(CSHandle *fh)
{
	uint64_t val=0;
	for(int i=0;i<sizeof(val);i++) val=(val<<8)|[fh readBitsLE:8];
	return val;
}

NSData *ReadSitxString(CSHandle *fh)
{
	int len=(int)ReadSitxP2(fh);
	NSData *data=[fh readDataOfLength:len];
	[fh flushReadBits];
	return data;
}

NSData *ReadSitxData(CSHandle *fh,int n)
{
	NSMutableData *data=[NSMutableData data];
	for(int i=0;i<n;i++)
	{
		uint8_t byte=[fh readBitsLE:8];
		[data appendBytes:&byte length:1];
	}
	return data;
}





uint64_t CSInputNextSitxP2(CSInputBuffer *input)
{
	int n=1;
	while(CSInputNextBitLE(input)==1) n++;

	uint64_t value=0;
	uint64_t bit=1;

	while(n)
	{
		if(CSInputNextBitLE(input)==1)
		{
			n--;
			value|=bit;
		}
		bit<<=1;
	}
	return value-1;
}
