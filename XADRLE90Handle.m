/*
 * XADRLE90Handle.m
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
#import "XADRLE90Handle.h"
#import "XADException.h"

@implementation XADRLE90Handle

-(id)initWithHandle:(CSHandle *)handle
{
	return [self initWithHandle:handle length:CSHandleMaxLength];
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length
{
	return [super initWithInputBufferForHandle:handle length:length];
}

-(void)resetByteStream
{
	repeatedbyte=count=0;
}

-(uint8_t)produceByteAtOffset:(off_t)pos
{
	if(count)
	{
		count--;
		return repeatedbyte;
	}
	else
	{
		if(CSInputAtEOF(input)) CSByteStreamEOF(self);

		uint8_t b=CSInputNextByte(input);

		if(b!=0x90) return repeatedbyte=b;
		else
		{
			uint8_t c=CSInputNextByte(input);
			if(c==0) return repeatedbyte=0x90;
			else
			{
				if(c==1) [XADException raiseDecrunchException];
				count=c-2;
				return repeatedbyte;
			}
		}
	}
}

@end
