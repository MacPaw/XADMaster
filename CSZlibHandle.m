/*
 * CSZlibHandle.m
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
#import "CSZlibHandle.h"



NSString *CSZlibException=@"CSZlibException";



@implementation CSZlibHandle


+(CSZlibHandle *)zlibHandleWithHandle:(CSHandle *)handle
{
	return [[[CSZlibHandle alloc] initWithHandle:handle length:CSHandleMaxLength header:YES] autorelease];
}

+(CSZlibHandle *)zlibHandleWithHandle:(CSHandle *)handle length:(off_t)length
{
	return [[[CSZlibHandle alloc] initWithHandle:handle length:length header:YES] autorelease];
}

+(CSZlibHandle *)deflateHandleWithHandle:(CSHandle *)handle
{
	return [[[CSZlibHandle alloc] initWithHandle:handle length:CSHandleMaxLength header:NO] autorelease];
}

+(CSZlibHandle *)deflateHandleWithHandle:(CSHandle *)handle length:(off_t)length
{
	return [[[CSZlibHandle alloc] initWithHandle:handle length:length header:NO] autorelease];
}




-(id)initWithHandle:(CSHandle *)handle length:(off_t)length header:(BOOL)header
{
	if(self=[super initWithParentHandle:handle length:length])
	{
		startoffs=[parent offsetInFile];
		inited=YES;
		seekback=NO;

		memset(&zs,0,sizeof(zs));

		if(header) inflateInit(&zs);
		else inflateInit2(&zs,-MAX_WBITS);
	}
	return self;
}

-(id)initAsCopyOf:(CSZlibHandle *)other
{
	if(self=[super initAsCopyOf:other])
	{
		startoffs=other->startoffs;
		inited=NO;
		seekback=other->seekback;

		memset(&zs,0,sizeof(zs));

		if(inflateCopy(&zs,&other->zs)==Z_OK)
		{
			zs.next_in=inbuffer;
			memcpy(inbuffer,other->zs.next_in,zs.avail_in);

			inited=YES;
			return self;
		}

		[self release];
	}
	return nil;
}

-(void)dealloc
{
	if(inited) inflateEnd(&zs);

	[super dealloc];
}

-(void)setSeekBackAtEOF:(BOOL)seekateof { seekback=seekateof; }

-(void)setEndStreamAtInputEOF:(BOOL)endateof { endstreamateof=endateof; } // Hack for NSIS's broken zlib usage

-(void)resetStream
{
	[parent seekToFileOffset:startoffs];
	zs.avail_in=0;
	inflateReset(&zs);
}

-(int)streamAtMost:(int)num toBuffer:(void *)buffer
{
	zs.next_out=buffer;
	zs.avail_out=num;

	for(;;)
	{
		int err=inflate(&zs,0);
		if(err==Z_STREAM_END)
		{
			if(seekback) [parent skipBytes:-(off_t)zs.avail_in];
			[self endStream];
			return num-zs.avail_out;
		}
		else if(err!=Z_OK && err!=Z_BUF_ERROR) [self _raiseZlib];

		if(!zs.avail_out) return num;

		if(!zs.avail_in)
		{
			zs.avail_in=[parent readAtMost:sizeof(inbuffer) toBuffer:inbuffer];
			zs.next_in=(void *)inbuffer;

			if(!zs.avail_in)
			{
				if(endstreamateof)
				{
					[self endStream];
					return num-zs.avail_out;
				}
				else [parent _raiseEOF];
			}
		}
	}
}

-(void)_raiseZlib
{
	[NSException raise:CSZlibException
	format:@"Zlib error while attepting to read from \"%@\": %s.",[self name],zs.msg];
}

@end
