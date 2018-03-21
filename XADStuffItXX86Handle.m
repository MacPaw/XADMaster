/*
 * XADStuffItXX86Handle.m
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
#import "XADStuffItXX86Handle.h"
#import "XADException.h"

@implementation XADStuffItXX86Handle

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length
{
	return [super initWithInputBufferForHandle:handle length:length];
}

-(void)resetByteStream
{
	lasthit=-6;
	bitfield=0;

	numbufferbytes=0;
	currbufferbyte=0;
}

-(uint8_t)produceByteAtOffset:(off_t)pos
{
	if(currbufferbyte<numbufferbytes) return buffer[currbufferbyte++];

	if(CSInputAtEOF(input)) CSByteStreamEOF(self);

	uint8_t b=CSInputNextByte(input);

	if(b==0xe8||b==0xe9)
	{
		int dist=(int)(pos-lasthit);
		lasthit=pos;

		if(dist>5)
		{
			bitfield=0;
		}
		else
		{
			for(int i=0;i<dist;i++)
			{
				bitfield=(bitfield&0x77)<<1;
			}
		}

		// Read offset into buffer.
		for(int i=0;i<4;i++)
		{
/*			if(CSInputAtEOF(input))
			{
				currbufferbyte=0;
				numbufferbytes=i;
				return b;
			}*/

			buffer[i]=CSInputPeekByte(input,i);
		}

		static const BOOL table[8]={YES,YES,YES,NO,YES,NO,NO,NO};

		if(buffer[3]==0x00 || buffer[3]==0xff)
		{
			if(table[(bitfield>>1)&0x07] && (bitfield>>1)<=0x0f)
			{
				int32_t absaddress=CSInt32LE(buffer);
				int32_t reladdress;

				for(;;)
				{
					reladdress=absaddress-(int32_t)pos-6;
					if(bitfield==0) break;

					static const int shifts[8]={24,16,8,8,0,0,0,0};
					int shift=shifts[bitfield>>1];
					int something=(reladdress>>shift)&0xff;
					if(something!=0&&something!=0xff) break;
					absaddress=reladdress^((1<<(shift+8))-1);
				}

				reladdress&=0x1ffffff;
				if(reladdress>=0x1000000) reladdress|=0xff000000;

				CSSetInt32LE(buffer,reladdress);
				currbufferbyte=0;
				numbufferbytes=4;

				bitfield=0;

				CSInputSkipBytes(input,4);
			}
			else
			{
				bitfield|=0x11;
			}
		}
		else
		{
			bitfield|=0x01;
		}
	}

	return b;
}

@end
