/*
 * XADStacLZSHandle.m
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

#import "XADStacLZSHandle.h"
#import "XADException.h"

// Stac LZS. Originally used in Stacker, also used in hardware-accelerated DiskDoubler,
// and communication protocols.
// Very simple LZSS with 2k window. However, match lengths are unbounded and can be longer
// than the window.

@implementation XADStacLZSHandle

-(id)initWithHandle:(CSHandle *)handle
{
	return [self initWithHandle:handle length:CSHandleMaxLength];
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length
{
	if((self=[super initWithInputBufferForHandle:handle length:length windowSize:2048]))
	{
		lengthcode=[XADPrefixCode new];

		[lengthcode addValue:2 forCodeWithHighBitFirst:0x00 length:2];
		[lengthcode addValue:3 forCodeWithHighBitFirst:0x01 length:2];
		[lengthcode addValue:4 forCodeWithHighBitFirst:0x02 length:2];
		[lengthcode addValue:5 forCodeWithHighBitFirst:0x0c length:4];
		[lengthcode addValue:6 forCodeWithHighBitFirst:0x0d length:4];
		[lengthcode addValue:7 forCodeWithHighBitFirst:0x0e length:4];
		[lengthcode addValue:8 forCodeWithHighBitFirst:0x0f length:4];
	}
	return self;
}

-(void)dealloc
{
	[lengthcode release];
	[super dealloc];
}

-(void)resetLZSSHandle
{
	extralength=0;
}

-(void)expandFromPosition:(off_t)pos
{
	while(XADLZSSShouldKeepExpanding(self))
	{
		if(extralength)
		{
			if(extralength>2048)
			{
				XADEmitLZSSMatch(self,extraoffset,2048,&pos);
				extralength-=2048;
			}
			else
			{
				XADEmitLZSSMatch(self,extraoffset,extralength,&pos);
				extralength=0;
			}
			continue;
		}

		if(CSInputNextBit(input)==0)
		{
			int byte=CSInputNextBitString(input,8);
			XADEmitLZSSLiteral(self,byte,&pos);
		}
		else
		{
			int offset;
			if(CSInputNextBit(input)==1) offset=CSInputNextBitString(input,7);
			else
			{
				int offsethigh=CSInputNextBitString(input,7);
				if(offsethigh==0)
				{
					[self endLZSSHandle];
					return;
				}

				offset=(offsethigh<<4)|CSInputNextBitString(input,4);
			}

			int length=CSInputNextSymbolUsingCode(input,lengthcode);
			if(length==8)
			{
				for(;;)
				{
					int code=CSInputNextBitString(input,4);
					length+=code;

					if(code!=15) break;
				}
			}

			if(offset>pos) [XADException raiseDecrunchException];

			if(length<=2048)
			{
				XADEmitLZSSMatch(self,offset,length,&pos);
			}
			else
			{
				XADEmitLZSSMatch(self,offset,2048,&pos);
				extralength=length-2048;
				extraoffset=offset;
			}
		}
	}
}

@end

