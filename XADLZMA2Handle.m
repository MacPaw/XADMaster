/*
 * XADLZMA2Handle.m
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

#import "XADLZMA2Handle.h"
#import "XADException.h"

static void *Alloc(void *p,size_t size) { return malloc(size); }
static void Free(void *p,void *address) { return free(address); }
static ISzAlloc allocator={Alloc,Free};

@implementation XADLZMA2Handle

-(id)initWithHandle:(CSHandle *)handle propertyData:(NSData *)propertydata
{
	return [self initWithHandle:handle length:CSHandleMaxLength propertyData:propertydata];
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length propertyData:(NSData *)propertydata
{
	if(self=[super initWithParentHandle:handle length:length])
	{
		startoffs=[parent offsetInFile];
		seekback=NO;

		Lzma2Dec_Construct(&lzma);
		if([propertydata length]>=1)
		if(Lzma2Dec_Allocate(&lzma,((uint8_t *)[propertydata bytes])[0],&allocator)==SZ_OK)
		{
			return self;
		}
	}

	[self release];
	return nil;
}

-(void)dealloc
{
	Lzma2Dec_Free(&lzma,&allocator);

	[super dealloc];

}

-(void)setSeekBackAtEOF:(BOOL)seekateof { seekback=seekateof; }

-(void)resetStream
{
	[parent seekToFileOffset:startoffs];
	Lzma2Dec_Init(&lzma);
	bufbytes=bufoffs=0;
}

-(int)streamAtMost:(int)num toBuffer:(void *)buffer
{
	int total=0;

	while(total<num)
	{
		size_t destlen=num-total;
		size_t srclen=bufbytes-bufoffs;
		ELzmaStatus status;

		int res=Lzma2Dec_DecodeToBuf(&lzma,buffer+total,&destlen,inbuffer+bufoffs,&srclen,LZMA_FINISH_ANY,&status);

		total+=destlen;
		bufoffs+=srclen;

		if(res!=SZ_OK) [XADException raiseDecrunchException];
		if(status==LZMA_STATUS_NEEDS_MORE_INPUT)
		{
			bufbytes=[parent readAtMost:sizeof(inbuffer) toBuffer:inbuffer];
			if(!bufbytes) [parent _raiseEOF];
			bufoffs=0;
		}
		else if(status==LZMA_STATUS_FINISHED_WITH_MARK)
		{
			if(seekback) [parent skipBytes:-bufbytes+bufoffs];
			[self endStream];
			break;
		}
	}

	return total;
}

@end

