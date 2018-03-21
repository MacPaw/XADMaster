/*
 * CSByteStreamHandle.m
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

NSString *CSByteStreamEOFReachedException=@"CSByteStreamEOFReachedException";

@implementation CSByteStreamHandle

/*-(id)initWithName:(NSString *)descname length:(off_t)length
{
	if(self=[super initWithName:descname length:length])
	{
		bytestreamproducebyte_ptr=(uint8_t (*)(id,SEL,off_t))[self methodForSelector:@selector(produceByteAtOffset:)];
	}
	return self;
}*/

-(id)initWithInputBufferForHandle:(CSHandle *)handle length:(off_t)length bufferSize:(int)buffersize;
{
	if(self=[super initWithInputBufferForHandle:handle length:length bufferSize:buffersize])
	{
		bytestreamproducebyte_ptr=(uint8_t (*)(id,SEL,off_t))[self methodForSelector:@selector(produceByteAtOffset:)];
	}
	return self;
}

-(id)initAsCopyOf:(CSByteStreamHandle *)other
{
	[self _raiseNotSupported:_cmd];
	return nil;
}



-(int)streamAtMost:(int)num toBuffer:(void *)buffer
{
	bytesproduced=0;

	if(setjmp(eofenv)==0)
	{
		while(bytesproduced<num)
		{
			uint8_t byte=bytestreamproducebyte_ptr(self,@selector(produceByteAtOffset:),streampos+bytesproduced);
			((uint8_t *)buffer)[bytesproduced++]=byte;
			if(endofstream) break;
		}
	}
	else
	{
		[self endStream];
	}

	return bytesproduced;
}

-(void)resetStream
{
	[self resetByteStream];
}

-(void)resetByteStream {}

-(uint8_t)produceByteAtOffset:(off_t)pos { return 0; }

-(void)endByteStream { [self endStream]; }

@end
