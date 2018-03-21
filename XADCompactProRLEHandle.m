/*
 * XADCompactProRLEHandle.m
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
#import "XADCompactProRLEHandle.h"

@implementation XADCompactProRLEHandle:CSByteStreamHandle

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length
{
	return [super initWithInputBufferForHandle:handle length:length];
}

-(void)resetByteStream
{
	saved=0;
	repeat=0;
	halfescaped=NO;
}

-(uint8_t)produceByteAtOffset:(off_t)pos
{
//NSLog(@"rle %d %d",(int)pos,(int)CSInputBufferOffset(input));
	if(repeat)
	{
		repeat--;
		return saved;
	}

	int byte;
	if(halfescaped)
	{
		byte=0x81;
		halfescaped=NO;
	}
	else byte=CSInputNextByte(input);

	if(byte==0x81)
	{
		byte=CSInputNextByte(input);
		if(byte==0x82)
		{
			byte=CSInputNextByte(input);
			if(byte!=0)
			{
				repeat=byte-2; // ?
				return saved;
			}
			else
			{
				repeat=1;
				saved=0x82;
				return 0x81;
			}
		}
		else
		{
			if(byte==0x81)
			{
				halfescaped=YES;
				return saved=0x81;
			}
			else
			{
				repeat=1;
				saved=byte;
				return 0x81;
			} 
		}
	}
	else return saved=byte;
}

@end

