/*
 * XADCABBlockHandle.h
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
#import "CSBlockStreamHandle.h"
#import "XADCABBlockReader.h"


@interface XADCABBlockHandle:CSBlockStreamHandle
{
	XADCABBlockReader *blocks;
	uint8_t inbuffer[32768+6144];
}

-(id)initWithBlockReader:(XADCABBlockReader *)blockreader;
-(void)dealloc;

-(void)resetBlockStream;
-(int)produceBlockAtOffset:(off_t)pos;

-(void)resetCABBlockHandle;
-(int)produceCABBlockWithInputBuffer:(uint8_t *)buffer length:(int)length atOffset:(off_t)pos length:(int)uncomplength;

@end

@interface XADCABCopyHandle:XADCABBlockHandle

-(int)produceCABBlockWithInputBuffer:(uint8_t *)buffer length:(int)length atOffset:(off_t)pos length:(int)uncomplength;

@end
