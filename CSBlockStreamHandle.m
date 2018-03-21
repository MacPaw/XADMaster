/*
 * CSBlockStreamHandle.m
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

static inline int imin(int a,int b) { return a<b?a:b; }

@implementation CSBlockStreamHandle

/*-(id)initWithName:(NSString *)descname length:(off_t)length
{
	if(self=[super initWithName:descname length:length])
	{
		_currblock=NULL;
		_blockstartpos=0;
		_blocklength=0;
	}
	return self;
}*/

-(id)initWithInputBufferForHandle:(CSHandle *)handle length:(off_t)length bufferSize:(int)buffersize;
{
	if(self=[super initWithInputBufferForHandle:handle length:length bufferSize:buffersize])
	{
		_currblock=NULL;
		_blockstartpos=0;
		_blocklength=0;
	}
	return self;
}

-(id)initAsCopyOf:(CSBlockStreamHandle *)other
{
	[self _raiseNotSupported:_cmd];
	return nil;
}




-(void)seekToFileOffset:(off_t)offs
{
	if(![self _prepareStreamSeekTo:offs]) return;

	if(offs<_blockstartpos) [super seekToFileOffset:0];

	while(_blockstartpos+_blocklength<offs)
	{
		[self _readNextBlock];
		if(endofstream)
		{
			if(offs==_blockstartpos) break;
			else [self _raiseEOF];
		}
	}

	streampos=offs;
}

-(void)resetStream
{
	_blockstartpos=0;
	_blocklength=0;
	_endofblocks=NO;
	[self resetBlockStream];
}

-(int)streamAtMost:(int)num toBuffer:(void *)buffer
{
	int n=0;

	if(streampos>=_blockstartpos&&streampos<_blockstartpos+_blocklength)
	{
		if(!_currblock) return 0;

		int offs=(int)(streampos-_blockstartpos);
		int count=_blocklength-offs;
		if(count>num) count=num;
		memcpy(buffer,_currblock+offs,count);
		n+=count;
	}

	while(n<num)
	{
		[self _readNextBlock];
		if(endofstream) break;

		int count=imin(_blocklength,num-n);
		memcpy(buffer+n,_currblock,count);
		n+=count;
	}

	return n;
}

-(void)_readNextBlock
{
	_blockstartpos+=_blocklength;
	if(_endofblocks) { [self endStream]; return; }
	_blocklength=[self produceBlockAtOffset:_blockstartpos];

	if(_blocklength<=0||!_currblock) [self endStream];
}

-(void)resetBlockStream { }

-(int)produceBlockAtOffset:(off_t)pos { return 0; }



-(void)setBlockPointer:(uint8_t *)blockpointer
{
	_currblock=blockpointer;
}

-(void)endBlockStream
{
	_endofblocks=YES;
}

@end
