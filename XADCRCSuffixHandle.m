/*
 * XADCRCSuffixHandle.m
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
#import "XADCRCSuffixHandle.h"

@implementation XADCRCSuffixHandle

+(XADCRCSuffixHandle *)IEEECRC32SuffixHandleWithHandle:(CSHandle *)handle CRCHandle:(CSHandle *)crchandle
bigEndianCRC:(BOOL)bigendian conditioned:(BOOL)conditioned
{
	if(conditioned) return [[[self alloc] initWithHandle:handle CRCHandle:crchandle initialCRC:0xffffffff
	CRCSize:4 bigEndianCRC:bigendian CRCTable:XADCRCTable_edb88320] autorelease];
	else return [[[self alloc] initWithHandle:handle CRCHandle:crchandle initialCRC:0
	CRCSize:4 bigEndianCRC:bigendian CRCTable:XADCRCTable_edb88320] autorelease];
}

+(XADCRCSuffixHandle *)CCITTCRC16SuffixHandleWithHandle:(CSHandle *)handle CRCHandle:(CSHandle *)crchandle
bigEndianCRC:(BOOL)bigendian conditioned:(BOOL)conditioned
{
	// Evil trick: negating the big endian flag does the same thing as XADUnReverseCRC16()
	if(conditioned) return [[[self alloc] initWithHandle:handle CRCHandle:crchandle initialCRC:0xffff
	CRCSize:2 bigEndianCRC:!bigendian  CRCTable:XADCRCReverseTable_1021] autorelease];
	else return [[[self alloc] initWithHandle:handle CRCHandle:crchandle initialCRC:0
	CRCSize:2 bigEndianCRC:!bigendian CRCTable:XADCRCReverseTable_1021] autorelease];
}

-(id)initWithHandle:(CSHandle *)handle CRCHandle:(CSHandle *)crchandle initialCRC:(uint32_t)initialcrc
CRCSize:(int)crcbytes bigEndianCRC:(BOOL)bigendian CRCTable:(const uint32_t *)crctable
{
	if(self=[super initWithParentHandle:handle])
	{
		crcparent=[crchandle retain];
		crcsize=crcbytes;
		bigend=bigendian;
		crc=initcrc=initialcrc;
		table=crctable;
		didtest=wascorrect=NO;
	}
	return self;
}

-(void)dealloc
{
	[crcparent release];
	[super dealloc];
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
	if(didtest) return wascorrect;
	if([parent hasChecksum]&&![parent isChecksumCorrect]) return NO;
	if(![parent atEndOfFile]) return NO; 

	if(crcparent)
	{
		@try {
			if(bigend&&crcsize==2) compcrc=[crcparent readUInt16BE];
			else if(bigend&&crcsize==4) compcrc=[crcparent readUInt32BE];
			else if(!bigend&&crcsize==2) compcrc=[crcparent readUInt16LE];
			else if(!bigend&&crcsize==4) compcrc=[crcparent readUInt32LE];
		} @catch(id e) { compcrc=(crc+1)^initcrc; }  // make sure check fails if reading failed
		[crcparent release];
		crcparent=nil;
	}

	didtest=YES;
	wascorrect=((crc^initcrc)==compcrc);

	return wascorrect;
}

-(double)estimatedProgress { return [parent estimatedProgress]; }

@end


