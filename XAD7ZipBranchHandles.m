/*
 * XAD7ZipBranchHandles.m
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

#import "XAD7ZipBranchHandles.h"

#if !__LP64__
#define _LZMA_UINT32_IS_ULONG
#endif

#define Byte LzmaByte
#define UInt16 LzmaUInt16
#define UInt32 LzmaUInt32
#define UInt64 LzmaUInt64
#import "lzma/Bra.h"

@implementation XAD7ZipBranchHandle

-(id)initWithHandle:(CSHandle *)handle
{
	return [self initWithHandle:handle length:CSHandleMaxLength propertyData:nil];
}

-(id)initWithHandle:(CSHandle *)handle propertyData:(NSData *)propertydata
{
	return [self initWithHandle:handle length:CSHandleMaxLength propertyData:propertydata];
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length
{
	return [self initWithHandle:handle length:length propertyData:nil];
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length propertyData:(NSData *)propertydata
{
	if((self=[super initWithParentHandle:handle length:length]))
	{
		startoffs=[handle offsetInFile];

		if(propertydata&&[propertydata length]>=4) baseoffset=CSUInt32LE([propertydata bytes]);
		else baseoffset=0;

		[self setBlockPointer:inbuffer];
	}
	return self;
}

-(void)resetBlockStream
{
	[parent seekToFileOffset:startoffs];
	leftoverstart=leftoverlength=0;
}

-(int)produceBlockAtOffset:(off_t)pos
{
	memmove(inbuffer,inbuffer+leftoverstart,leftoverlength);

	int bytesread=[parent readAtMost:sizeof(inbuffer)-leftoverlength toBuffer:inbuffer+leftoverlength];
	if(bytesread==0)
	{
		[self endBlockStream];

		if(leftoverlength) return leftoverlength;
		else return 0;
	}

	int processed=[self decodeBlock:inbuffer length:bytesread+leftoverlength offset:pos+baseoffset];
	leftoverstart=processed;
	leftoverlength=bytesread+leftoverlength-processed;

	return processed;
}

-(int)decodeBlock:(uint8_t *)block length:(int)length offset:(off_t)pos { return 0; }

@end



@implementation XAD7ZipBCJHandle
-(void)resetBlockStream
{
	[super resetBlockStream];
	x86_Convert_Init(state);
}
-(int)decodeBlock:(uint8_t *)block length:(int)length offset:(off_t)pos
{ return x86_Convert(block,length,(UInt32)pos,(UInt32 *)&state,0); }
@end

@implementation XAD7ZipPPCHandle
-(int)decodeBlock:(uint8_t *)block length:(int)length offset:(off_t)pos
{ return PPC_Convert(block,length,(UInt32)pos,0); }
@end

@implementation XAD7ZipIA64Handle
-(int)decodeBlock:(uint8_t *)block length:(int)length offset:(off_t)pos
{ return IA64_Convert(block,length,(UInt32)pos,0); }
@end

@implementation XAD7ZipARMHandle
-(int)decodeBlock:(uint8_t *)block length:(int)length offset:(off_t)pos
{ return ARM_Convert(block,length,(UInt32)pos,0); }
@end

@implementation XAD7ZipThumbHandle
-(int)decodeBlock:(uint8_t *)block length:(int)length offset:(off_t)pos
{ return ARMT_Convert(block,length,(UInt32)pos,0); }
@end

@implementation XAD7ZipSPARCHandle
-(int)decodeBlock:(uint8_t *)block length:(int)length offset:(off_t)pos
{ return SPARC_Convert(block,length,(UInt32)pos,0); }
@end
