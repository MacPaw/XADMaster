/*
 * XADMSZipHandle.m
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
#import "XADMSZipHandle.h"

#ifndef __MACTYPES__
#define Byte zlibByte
#include <zlib.h>
#undef Byte
#else
#include <zlib.h>
#endif

@implementation XADMSZipHandle

-(int)produceCABBlockWithInputBuffer:(uint8_t *)buffer length:(int)length atOffset:(off_t)pos length:(int)uncomplength
{
	z_stream zs;
	memset(&zs,0,sizeof(zs));

	inflateInit2(&zs,-MAX_WBITS);
	if(pos!=0) inflateSetDictionary(&zs,outbuffer,lastlength);

	zs.avail_in=length-2;
	zs.next_in=buffer+2;

	zs.next_out=outbuffer;
	zs.avail_out=uncomplength; //sizeof(outbuffer);

	/*int err=*/inflate(&zs,0);
	inflateEnd(&zs);
	/*if(err==Z_STREAM_END)
	{
		if(seekback) [parent skipBytes:-(off_t)zs.avail_in];
		[self endStream];
		break;
	}
	else if(err!=Z_OK) [self _raiseZlib];*/

	[self setBlockPointer:outbuffer];

	lastlength=sizeof(outbuffer)-zs.avail_out;
	return lastlength;
}

@end
