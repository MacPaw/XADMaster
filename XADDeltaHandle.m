/*
 * XADDeltaHandle.m
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
#import "XADDeltaHandle.h"

@implementation XADDeltaHandle

-(id)initWithHandle:(CSHandle *)handle
{
	return [self initWithHandle:handle length:CSHandleMaxLength deltaDistance:1];
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length
{
	return [self initWithHandle:handle length:length deltaDistance:1];
}

-(id)initWithHandle:(CSHandle *)handle deltaDistance:(int)deltadistance
{
	return [self initWithHandle:handle length:CSHandleMaxLength deltaDistance:deltadistance];
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length deltaDistance:(int)deltadistance
{
	if((self=[super initWithInputBufferForHandle:handle length:length]))
	{
		distance=deltadistance;
	}
	return self;
}

-(id)initWithHandle:(CSHandle *)handle propertyData:(NSData *)propertydata
{
	return [self initWithHandle:handle length:CSHandleMaxLength propertyData:propertydata];
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length propertyData:(NSData *)propertydata
{
	int deltadistance=1;

	if(propertydata&&[propertydata length]>=1)
	deltadistance=((uint8_t *)[propertydata bytes])[0]+1;

	return [self initWithHandle:handle length:length deltaDistance:deltadistance];
}

-(void)resetByteStream
{
	memset(deltabuffer,0,sizeof(deltabuffer));
}

-(uint8_t)produceByteAtOffset:(off_t)pos
{
	if(CSInputAtEOF(input)) CSByteStreamEOF(self);

	uint8_t b=CSInputNextByte(input);
	uint8_t old=deltabuffer[(pos-distance+0x100)&0xff];
	uint8_t new=b+old;

	deltabuffer[pos&0xff]=new;
	return new;
}

@end
