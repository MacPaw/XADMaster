/*
 * XADMD5Handle.m
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
#import "XADMD5Handle.h"

@implementation XADMD5Handle

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
	MD5_Init(&context);
	[parent seekToFileOffset:0];
}

-(int)streamAtMost:(int)num toBuffer:(void *)buffer
{
	int actual=[parent readAtMost:num toBuffer:buffer];
	MD5_Update(&context,buffer,actual);
	return actual;
}

-(BOOL)hasChecksum { return YES; }

-(BOOL)isChecksumCorrect
{
	if([digest length]!=16) return NO;

	MD5_CTX copy;
	copy=context;

	uint8_t buf[16];
	MD5_Final(buf,&copy);

	return memcmp([digest bytes],buf,16)==0;
}

-(double)estimatedProgress { return [parent estimatedProgress]; }

@end


