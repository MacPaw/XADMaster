/*
 * XAD7ZipBCJ2Handle.h
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
#import "CSByteStreamHandle.h"

@interface XAD7ZipBCJ2Handle:CSByteStreamHandle
{
	CSHandle *calls,*jumps,*ranges;
	off_t callstart,jumpstart,rangestart;

	uint16_t probabilities[258];
	uint32_t range,code;

	int prevbyte;
	uint32_t val;
	int valbyte;
}

-(id)initWithHandle:(CSHandle *)handle callHandle:(CSHandle *)callhandle
jumpHandle:(CSHandle *)jumphandle rangeHandle:(CSHandle *)rangehandle length:(off_t)length;
-(void)dealloc;
-(void)resetByteStream;
-(uint8_t)produceByteAtOffset:(off_t)pos;

@end
