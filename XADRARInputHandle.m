/*
 * XADRARInputHandle.m
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
#import "XADRARInputHandle.h"
#import "XADException.h"
#import "CRC.h"

@implementation XADRARInputHandle

-(id)initWithHandle:(CSHandle *)handle parts:(NSArray *)partarray
{
	off_t totallength=0;
	NSEnumerator *enumerator=[partarray objectEnumerator];
	NSDictionary *dict;
	while((dict=[enumerator nextObject]))
	{
		totallength+=[[dict objectForKey:@"InputLength"] longLongValue];
	}

	if((self=[super initWithParentHandle:handle length:totallength]))
	{
		parts=[partarray retain];
	}
	return self;
}

-(void)dealloc
{
	[parts release];
	[super dealloc];
}

-(void)resetStream
{
	part=0;
	partend=0;

	[self startNextPart];
}

-(int)streamAtMost:(int)num toBuffer:(void *)buffer
{
	uint8_t *bytebuf=buffer;
	int total=0;
	while(total<num)
	{
		if(streampos+total>=partend) [self startNextPart];

		int numbytes=num-total;
		if(streampos+total+numbytes>=partend) numbytes=(int)(partend-streampos-total);

		[parent readBytes:numbytes toBuffer:&bytebuf[total]];

        crc=XADCalculateCRCFast(crc,&bytebuf[total],numbytes,XADCRCTable_sliced16_edb88320);

		total+=numbytes;

		// RAR CRCs are for compressed and encrypted data for all parts
		// except the last one, where it is for descrypted and uncompressed data.
		// Check the CRC on all parts but the last.
		// TODO: Add blake2sp
		if(streampos+total>=partend) // If at the end a block,
		if(partend!=streamlength) // but not the end of the file,
		if(correctcrc!=0xffffffff) // and there is a correct CRC available,
		if(~crc!=correctcrc) [XADException raiseChecksumException]; // check it.
	}

	return num;
}

-(void)startNextPart
{
	if(part>=[parts count]) [XADException raiseInputException];
	NSDictionary *dict=[parts objectAtIndex:part];
	part++;

	off_t offset=[[dict objectForKey:@"Offset"] longLongValue];
	off_t length=[[dict objectForKey:@"InputLength"] longLongValue];

	[parent seekToFileOffset:offset];
	partend+=length;

	crc=0xffffffff;
	NSNumber *crcnum=[dict objectForKey:@"CRC32"];
	if(crcnum) correctcrc=[crcnum unsignedIntValue];
	else correctcrc=0xffffffff;
}

@end

