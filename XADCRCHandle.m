/*
 * XADCRCHandle.m
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
#import "XADCRCHandle.h"

@interface XADFastIEEECRC32Handle:XADCRCHandle
@end

@implementation XADCRCHandle

+(XADCRCHandle *)IEEECRC32HandleWithHandle:(CSHandle *)handle
correctCRC:(uint32_t)correctcrc conditioned:(BOOL)conditioned
{
	if(conditioned) return [[[XADFastIEEECRC32Handle alloc] initWithHandle:handle length:CSHandleMaxLength initialCRC:0xffffffff
	correctCRC:correctcrc^0xffffffff CRCTable:XADCRCTable_edb88320] autorelease];
	else return [[[XADFastIEEECRC32Handle alloc] initWithHandle:handle length:CSHandleMaxLength initialCRC:0
	correctCRC:correctcrc CRCTable:XADCRCTable_edb88320] autorelease];
}

+(XADCRCHandle *)IEEECRC32HandleWithHandle:(CSHandle *)handle length:(off_t)length
correctCRC:(uint32_t)correctcrc conditioned:(BOOL)conditioned
{
	if(conditioned) return [[[XADFastIEEECRC32Handle alloc] initWithHandle:handle length:length initialCRC:0xffffffff
	correctCRC:correctcrc^0xffffffff CRCTable:XADCRCTable_edb88320] autorelease];
	else return [[[XADFastIEEECRC32Handle alloc] initWithHandle:handle length:length initialCRC:0
	correctCRC:correctcrc CRCTable:XADCRCTable_edb88320] autorelease];
}

+(XADCRCHandle *)IBMCRC16HandleWithHandle:(CSHandle *)handle length:(off_t)length
correctCRC:(uint32_t)correctcrc conditioned:(BOOL)conditioned
{
	if(conditioned) return [[[self alloc] initWithHandle:handle length:length initialCRC:0xffff
	correctCRC:correctcrc^0xffff CRCTable:XADCRCTable_a001] autorelease];
	else return [[[self alloc] initWithHandle:handle length:length initialCRC:0
	correctCRC:correctcrc CRCTable:XADCRCTable_a001] autorelease];
}

+(XADCRCHandle *)CCITTCRC16HandleWithHandle:(CSHandle *)handle length:(off_t)length
correctCRC:(uint32_t)correctcrc conditioned:(BOOL)conditioned
{
	if(conditioned) return [[[self alloc] initWithHandle:handle length:length initialCRC:0xffff
	correctCRC:XADUnReverseCRC16(correctcrc)^0xffff CRCTable:XADCRCReverseTable_1021] autorelease];
	else return [[[self alloc] initWithHandle:handle length:length initialCRC:0
	correctCRC:XADUnReverseCRC16(correctcrc) CRCTable:XADCRCReverseTable_1021] autorelease];
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length initialCRC:(uint32_t)initialcrc
correctCRC:(uint32_t)correctcrc CRCTable:(const uint32_t *)crctable
{
	if((self=[super initWithParentHandle:handle length:length]))
	{
		crc=initcrc=initialcrc;
		compcrc=correctcrc;
        table=crctable;
		transformationfunction=NULL;
		transformationcontext=NULL;
	}
	return self;
}

-(void)dealloc
{
	[transformationcontext release];
	[super dealloc];
}

-(void)setCRCTransformationFunction:(XADCRCTransformationFunction *)function context:(id)context
{
	transformationfunction=function;
	[transformationcontext release];
	transformationcontext=[context retain];
}

-(void)resetStream
{
	[parent seekToFileOffset:0];
	crc=initcrc;
}

-(int)streamAtMost:(int)num toBuffer:(void *)buffer
{
	int actual=[parent readAtMost:num toBuffer:buffer];
	crc=XADCalculateCRC(crc,buffer,actual,table);
	return actual;
}

-(BOOL)hasChecksum { return YES; }

-(BOOL)isChecksumCorrect
{
	if([parent hasChecksum]&&![parent isChecksumCorrect]) return NO;

	if(transformationfunction)
	{
		uint32_t actualcrc=transformationfunction(crc,transformationcontext);
		return actualcrc==compcrc;
	}
	else
	{
		return crc==compcrc;
	}
}

-(double)estimatedProgress { return [parent estimatedProgress]; }

@end

@implementation XADFastIEEECRC32Handle

- (int)streamAtMost:(int)num toBuffer:(void *)buffer
{
    int actual=[parent readAtMost:num toBuffer:buffer];
    crc=XADCalculateCRCFast(crc,buffer,actual,XADCRCTable_sliced16_edb88320);
    return actual;
}
@end


