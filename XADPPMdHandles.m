/*
 * XADPPMdHandles.m
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
#import "XADPPMdHandles.h"
#import "XADException.h"




@implementation XADPPMdVariantGHandle

-(id)initWithHandle:(CSHandle *)handle maxOrder:(int)maxorder subAllocSize:(int)suballocsize
{
	return [self initWithHandle:handle length:CSHandleMaxLength maxOrder:maxorder subAllocSize:suballocsize];
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length maxOrder:(int)maxorder subAllocSize:(int)suballocsize
{
	if((self=[super initWithInputBufferForHandle:handle length:length]))
	{
		alloc=CreateSubAllocatorVariantG(suballocsize);
		max=maxorder;
	}
	return self;
}

-(void)dealloc
{
	FreeSubAllocatorVariantG(alloc);
	[super dealloc];
}

-(void)resetByteStream
{
	if(!StartPPMdModelVariantG(&model,(PPMdReadFunction *)CSInputNextByte,input,&alloc->core,max,NO))
	{
		[XADException raiseDecrunchException];
	}
}

-(uint8_t)produceByteAtOffset:(off_t)pos
{
	int byte=NextPPMdVariantGByte(&model);
	if(byte==-1) CSByteStreamEOF(self);
	else if(byte==-2) { [XADException raiseDecrunchException]; return 0; }
	else return byte;
}

@end




@implementation XADPPMdVariantHHandle

-(id)initWithHandle:(CSHandle *)handle maxOrder:(int)maxorder subAllocSize:(int)suballocsize
{
	return [self initWithHandle:handle length:CSHandleMaxLength maxOrder:maxorder subAllocSize:suballocsize];
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length maxOrder:(int)maxorder subAllocSize:(int)suballocsize
{
	if((self=[super initWithInputBufferForHandle:handle length:length]))
	{
		alloc=CreateSubAllocatorVariantH(suballocsize);
		max=maxorder;
	}
	return self;
}

-(void)dealloc
{
	FreeSubAllocatorVariantH(alloc);
	[super dealloc];
}

-(void)resetByteStream { StartPPMdModelVariantH(&model,(PPMdReadFunction *)CSInputNextByte,input,alloc,max,NO); }

-(uint8_t)produceByteAtOffset:(off_t)pos
{
	int byte=NextPPMdVariantHByte(&model);
	if(byte<0) CSByteStreamEOF(self);
	return byte;
}

@end




@implementation XADPPMdVariantIHandle

-(id)initWithHandle:(CSHandle *)handle maxOrder:(int)maxorder subAllocSize:(int)suballocsize modelRestorationMethod:(int)mrmethod
{
	return [self initWithHandle:handle length:CSHandleMaxLength maxOrder:maxorder subAllocSize:suballocsize modelRestorationMethod:mrmethod];
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length maxOrder:(int)maxorder subAllocSize:(int)suballocsize modelRestorationMethod:(int)mrmethod
{
	if((self=[super initWithInputBufferForHandle:handle length:length]))
	{
		alloc=CreateSubAllocatorVariantI(suballocsize);
		max=maxorder;
		method=mrmethod;
	}
	return self;
}

-(void)dealloc
{
	FreeSubAllocatorVariantI(alloc);
	[super dealloc];
}

-(void)resetByteStream
{
	if(max<2) [XADException raiseNotSupportedException];
	StartPPMdModelVariantI(&model,(PPMdReadFunction *)CSInputNextByte,input,alloc,max,method);
}

-(uint8_t)produceByteAtOffset:(off_t)pos
{
	int byte=NextPPMdVariantIByte(&model);
	if(byte<0) CSByteStreamEOF(self);
	return byte;
}

@end




@implementation XADStuffItXBrimstoneHandle

-(id)initWithHandle:(CSHandle *)handle maxOrder:(int)maxorder subAllocSize:(int)suballocsize
{
	return [self initWithHandle:handle length:CSHandleMaxLength maxOrder:maxorder subAllocSize:suballocsize];
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length maxOrder:(int)maxorder subAllocSize:(int)suballocsize
{
	if((self=[super initWithInputBufferForHandle:handle length:length]))
	{
		alloc=CreateSubAllocatorBrimstone(suballocsize);
		max=maxorder;
	}
	return self;
}

-(void)dealloc
{
	FreeSubAllocatorBrimstone(alloc);
	[super dealloc];
}

-(void)resetByteStream
{
	if(!StartPPMdModelVariantG(&model,(PPMdReadFunction *)CSInputNextByte,input,&alloc->core,max,YES))
	{
		[XADException raiseDecrunchException];
	}
}

-(uint8_t)produceByteAtOffset:(off_t)pos
{
	int byte=NextPPMdVariantGByte(&model);
	if(byte<0) CSByteStreamEOF(self);
	return byte;
}

@end



@implementation XAD7ZipPPMdHandle

-(void)resetByteStream { StartPPMdModelVariantH(&model,(PPMdReadFunction *)CSInputNextByte,input,alloc,max,YES); }

@end
