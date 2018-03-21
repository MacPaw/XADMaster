/*
 * CSSubHandle.m
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
#import "CSSubHandle.h"

@implementation CSSubHandle

-(id)initWithHandle:(CSHandle *)handle from:(off_t)from length:(off_t)length
{
	if((self=[super initWithParentHandle:handle]))
	{
		start=from;
		end=from+length;

		[parent seekToFileOffset:start];

		if(parent) return self;

		[self release];
	}
	return nil;
}

-(id)initAsCopyOf:(CSSubHandle *)other
{
	if(self=[super initAsCopyOf:other])
	{
		start=other->start;
		end=other->end;
	}
	return self;
}

-(void)dealloc
{
	[super dealloc];
}

-(off_t)startOffsetInParent { return start; }

-(off_t)fileSize
{
	return end-start;
/*	off_t parentsize=[parent fileSize];
	if(parentsize>end) return end-start;
	else if(parentsize<start) return 0;
	else return parentsize-start;*/
}

-(off_t)offsetInFile
{
	return [parent offsetInFile]-start;
}

-(BOOL)atEndOfFile
{
	return [parent offsetInFile]==end||[parent atEndOfFile];
}

-(void)seekToFileOffset:(off_t)offs
{
	if(offs<0) [self _raiseNotSupported:_cmd];
	if(offs>end) [self _raiseEOF];
	[parent seekToFileOffset:offs+start];
}

-(void)seekToEndOfFile
{
//	@try
	{
		[parent seekToFileOffset:end];
	}
/*	@catch(NSException *e)
	{
		if([[e name] isEqual:@"CSEndOfFileException"]) [parent seekToEndOfFile];
		else @throw;
	}*/
}

-(int)readAtMost:(int)num toBuffer:(void *)buffer
{
	off_t curr=[parent offsetInFile];
	if(curr+num>end) num=(int)(end-curr);
	if(num<=0) return 0;
	else return [parent readAtMost:num toBuffer:buffer];
}

-(NSString *)description
{
	return [NSString stringWithFormat:@"%@ @ %qu from %qu length %qu for %@",
	[self class],[self offsetInFile],start,end-start,[parent description]];
}

@end
