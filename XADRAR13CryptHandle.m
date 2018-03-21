/*
 * XADRAR13CryptHandle.m
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
#import "XADRAR13CryptHandle.h"

// TODO: Find test cases and actually test this code.

static inline uint16_t rol8(uint16_t val,int n) { return (val<<n)|(val>>(8-n)); }

@implementation XADRAR13CryptHandle

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length password:(NSData *)passdata
{
	if((self=[super initWithInputBufferForHandle:handle length:length]))
	{
		password=[passdata retain];
	}
	return self;
}

-(void)dealloc
{
	[password release];
	[super dealloc];
}



-(void)resetByteStream
{
	int passlength=[password length];
	const uint8_t *passbytes=[password bytes];

	key1=key2=key3=0;

	for(int i=0;i<passlength;i++)
	{
		uint8_t c=passbytes[i];
		key1+=c;
		key2^=c;
		key3+=c;
		key3=rol8(key3,1);
	}
}

-(uint8_t)produceByteAtOffset:(off_t)pos
{
	key2+=key3;
	key1+=key2;

	if(CSInputAtEOF(input)) CSByteStreamEOF(self);

	return CSInputNextByte(input)-key1;
}

@end
