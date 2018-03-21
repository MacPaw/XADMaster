/*
 * XADPPMdHandles.h
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
#import "PPMd/VariantG.h"
#import "PPMd/VariantH.h"
#import "PPMd/VariantI.h"
#import "PPMd/SubAllocatorVariantG.h"
#import "PPMd/SubAllocatorVariantH.h"
#import "PPMd/SubAllocatorVariantI.h"
#import "PPMd/SubAllocatorBrimstone.h"

@interface XADPPMdVariantGHandle:CSByteStreamHandle
{
	PPMdModelVariantG model;
	PPMdSubAllocatorVariantG *alloc;
	int max;
}

-(id)initWithHandle:(CSHandle *)handle maxOrder:(int)maxorder subAllocSize:(int)suballocsize;
-(id)initWithHandle:(CSHandle *)handle length:(off_t)length maxOrder:(int)maxorder subAllocSize:(int)suballocsize;
-(void)dealloc;

-(void)resetByteStream;
-(uint8_t)produceByteAtOffset:(off_t)pos;

@end

@interface XADPPMdVariantHHandle:CSByteStreamHandle
{
	PPMdModelVariantH model;
	PPMdSubAllocatorVariantH *alloc;
	int max;
}

-(id)initWithHandle:(CSHandle *)handle maxOrder:(int)maxorder subAllocSize:(int)suballocsize;
-(id)initWithHandle:(CSHandle *)handle length:(off_t)length maxOrder:(int)maxorder subAllocSize:(int)suballocsize;
-(void)dealloc;

-(void)resetByteStream;
-(uint8_t)produceByteAtOffset:(off_t)pos;

@end

@interface XADPPMdVariantIHandle:CSByteStreamHandle
{
	PPMdModelVariantI model;
	PPMdSubAllocatorVariantI *alloc;
	int max,method;
}

-(id)initWithHandle:(CSHandle *)handle maxOrder:(int)maxorder subAllocSize:(int)suballocsize modelRestorationMethod:(int)mrmethod;
-(id)initWithHandle:(CSHandle *)handle length:(off_t)length maxOrder:(int)maxorder subAllocSize:(int)suballocsize modelRestorationMethod:(int)mrmethod;
-(void)dealloc;

-(void)resetByteStream;
-(uint8_t)produceByteAtOffset:(off_t)pos;

@end

@interface XADStuffItXBrimstoneHandle:CSByteStreamHandle
{
	PPMdModelVariantG model;
	PPMdSubAllocatorBrimstone *alloc;
	int max;
}

-(id)initWithHandle:(CSHandle *)handle maxOrder:(int)maxorder subAllocSize:(int)suballocsize;
-(id)initWithHandle:(CSHandle *)handle length:(off_t)length maxOrder:(int)maxorder subAllocSize:(int)suballocsize;
-(void)dealloc;

-(void)resetByteStream;
-(uint8_t)produceByteAtOffset:(off_t)pos;

@end

@interface XAD7ZipPPMdHandle:XADPPMdVariantHHandle
{
}

-(void)resetByteStream;

@end
