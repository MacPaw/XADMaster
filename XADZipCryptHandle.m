/*
 * XADZipCryptHandle.m
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
#import "XADZipCryptHandle.h"
#import "XADException.h"
#import "CRC.h"

@implementation XADZipCryptHandle

static void UpdateKeys(XADZipCryptHandle *self,uint8_t b)
{
	self->key0=XADCRC(self->key0,b,XADCRCTable_edb88320);
	self->key1+=self->key0&0xff;
	self->key1=self->key1*134775813+1;
	self->key2=XADCRC(self->key2,self->key1>>24,XADCRCTable_edb88320);
}

static uint8_t DecryptByte(XADZipCryptHandle *self)
{
	uint16_t temp=self->key2|2;
	return (temp*(temp^1))>>8;
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length password:(NSData *)passdata testByte:(uint8_t)testbyte
{
	if((self=[super initWithInputBufferForHandle:handle length:length-12]))
	{
		password=[passdata retain];
		test=testbyte;
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
	key0=305419896;
	key1=591751049;
	key2=878082192;

	int passlength=[password length];
	const uint8_t *passbytes=[password bytes];
	for(int i=0;i<passlength;i++) UpdateKeys(self,passbytes[i]);

	for(int i=0;i<12;i++)
	{
		uint8_t b=CSInputNextByte(input)^DecryptByte(self);
		UpdateKeys(self,b);
		if(i==11&&b!=test) [XADException raisePasswordException];
	}
}

-(uint8_t)produceByteAtOffset:(off_t)pos
{
	uint8_t b=CSInputNextByte(input)^DecryptByte(self);
//NSLog(@"%02x",b);
	UpdateKeys(self,b);
	return b;
}

@end
