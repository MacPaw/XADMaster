/*
 * XADXORSumHandle.m
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
#import "XADXORSumHandle.h"

@implementation XADXORSumHandle

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length correctChecksum:(uint8_t)correct
{
	if((self=[super initWithParentHandle:handle length:length]))
	{
		correctchecksum=correct;
	}
	return self;
}

-(void)resetStream
{
	[parent seekToFileOffset:0];
	checksum=0;
}

-(int)streamAtMost:(int)num toBuffer:(void *)buffer
{
	int actual=[parent readAtMost:num toBuffer:buffer];

	uint8_t *bytes=buffer;
	for(int i=0;i<actual;i++) checksum^=bytes[i];

	return actual;
}

-(BOOL)hasChecksum { return YES; }

-(BOOL)isChecksumCorrect
{
	return checksum==correctchecksum;
}

-(double)estimatedProgress { return [parent estimatedProgress]; }

@end

