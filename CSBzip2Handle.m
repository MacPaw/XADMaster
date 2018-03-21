/*
 * CSBzip2Handle.m
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
#import "CSBzip2Handle.h"

NSString *CSBzip2Exception=@"CSBzip2Exception";

@implementation CSBzip2Handle

+(CSBzip2Handle *)bzip2HandleWithHandle:(CSHandle *)handle
{
	return [[[self alloc] initWithHandle:handle length:CSHandleMaxLength] autorelease];
}

+(CSBzip2Handle *)bzip2HandleWithHandle:(CSHandle *)handle length:(off_t)length
{
	return [[[self alloc] initWithHandle:handle length:length] autorelease];
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length
{
	if((self=[super initWithParentHandle:handle length:length]))
	{
		startoffs=[parent offsetInFile];
		inited=NO;
		checksumcorrect=YES;
	}
	return self;
}

-(void)dealloc
{
	if(inited) BZ2_bzDecompressEnd(&bzs);

	[super dealloc];
}

-(void)resetStream
{
	[parent seekToFileOffset:startoffs];

	if(inited) BZ2_bzDecompressEnd(&bzs);
	memset(&bzs,0,sizeof(bzs));
	BZ2_bzDecompressInit(&bzs,0,0);

	checksumcorrect=YES;
}

-(int)streamAtMost:(int)num toBuffer:(void *)buffer
{
	bzs.next_out=buffer;
	bzs.avail_out=num;

	while(bzs.avail_out)
	{
		if(!bzs.avail_in)
		{
			bzs.avail_in=[parent readAtMost:sizeof(inbuffer) toBuffer:inbuffer];
			bzs.next_in=(void *)inbuffer;

			if(!bzs.avail_in) [parent _raiseEOF];
		}

		int err=BZ2_bzDecompress(&bzs);
		if(err==BZ_STREAM_END)
		{
			// Attempt to find another concaternated bzip2 stream.

			// Move any remaining data to start of buffer.
			memmove(inbuffer,bzs.next_in,bzs.avail_in);
			bzs.next_in=(void *)inbuffer;

			// Fill up buffer.
			int spaceleft=sizeof(inbuffer)-bzs.avail_in;
			int more=[parent readAtMost:spaceleft toBuffer:inbuffer+bzs.avail_in];
			bzs.avail_in+=more;

			// Check for another stream header.
			if(bzs.avail_in<20||inbuffer[0]!='B'||inbuffer[1]!='Z'||inbuffer[2]!='h'
			||inbuffer[3]<'0'||inbuffer[3]>'9'||inbuffer[4]!=0x31||inbuffer[5]!=0x41
			||inbuffer[6]!=0x59||inbuffer[7]!=0x26||inbuffer[8]!=0x53||inbuffer[9]!=0x59)
			{
				// No other stream available, stop.
				[self endStream];
				break;
			}

			BZ2_bzDecompressEnd(&bzs);
			BZ2_bzDecompressInit(&bzs,0,0);
		}
		else if(err!=BZ_OK)
		{
			if(err==BZ_DATA_ERROR) checksumcorrect=NO;
			[self _raiseBzip2:err];
		}
	}

	return num-bzs.avail_out;
}

-(BOOL)hasChecksum { return YES; }

-(BOOL)isChecksumCorrect { return checksumcorrect; }

-(void)_raiseBzip2:(int)error
{
	[NSException raise:CSBzip2Exception
	format:@"Bzlib error while attepting to read from \"%@\": %d.",[self name],error];
}

@end

