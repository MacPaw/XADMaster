/*
 * XADSHA1Handle.m
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
#import "XADSHA1Handle.h"

@implementation XADSHA1Handle

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length correctDigest:(NSData *)correctdigest;
{
	if((self=[super initWithParentHandle:handle length:length]))
	{
		digest=[correctdigest retain];
	}
	return self;
}

-(void)dealloc
{
	[digest release];
	[super dealloc];
}

-(void)resetStream
{
	SHA1_Init(&context);
	[parent seekToFileOffset:0];
}

-(int)streamAtMost:(int)num toBuffer:(void *)buffer
{
	int actual=[parent readAtMost:num toBuffer:buffer];
	SHA1_Update(&context,buffer,actual);
	return actual;
}

-(BOOL)hasChecksum { return YES; }

-(BOOL)isChecksumCorrect
{
	if([digest length]!=20) return NO;

	SHA_CTX copy;
	copy=context;

	uint8_t buf[20];
	SHA1_Final(buf,&copy);

	return memcmp([digest bytes],buf,20)==0;
}

-(double)estimatedProgress { return [parent estimatedProgress]; }

@end


