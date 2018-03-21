/*
 * Scanning.m
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
#import "Scanning.h"

typedef struct ByteString
{
	const uint8_t *bytes;
	int length;
} ByteString;

static int MatchByteString(const uint8_t *bytes,int available,off_t offset,void *context)
{
	ByteString *bs=context;
	if(available<bs->length) return NO;
	return memcmp(bytes,bs->bytes,bs->length)==0;
}


@implementation CSHandle (Scanning)

-(BOOL)scanForByteString:(const void *)bytes length:(int)length
{
	ByteString bs={ .bytes=bytes, .length=length };
	return [self scanUsingMatchingFunction:MatchByteString maximumLength:length context:&bs];
}

-(int)scanUsingMatchingFunction:(CSByteMatchingFunctionPointer)function
maximumLength:(int)maximumlength
{
	return [self scanUsingMatchingFunction:function maximumLength:maximumlength context:NULL];
}

-(int)scanUsingMatchingFunction:(CSByteMatchingFunctionPointer)function
maximumLength:(int)maximumlength context:(void *)contextptr
{
	uint8_t buffer[65536];

	off_t pos=0;
	int actual=[self readAtMost:sizeof(buffer) toBuffer:buffer];

	while(actual>=maximumlength)
	{
		for(int i=0;i<=actual-maximumlength;i++)
		{
			int res=function(&buffer[i],actual-i,pos++,contextptr);
			if(res)
			{
				[self skipBytes:i-actual];
				return res;
			}
		}

		memcpy(buffer,&buffer[actual-maximumlength+1],maximumlength-1);
		actual=[self readAtMost:sizeof(buffer)-maximumlength+1 toBuffer:&buffer[maximumlength-1]]+maximumlength-1;
	}

	for(int i=0;i<actual;i++)
	{
		int res=function(&buffer[i],actual-i,pos++,contextptr);
		if(res)
		{
			[self skipBytes:i-actual];
			return res;
		}
	}

	return 0;
}

@end

