/*
 * XADCABBlockReader.m
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
#import "XADCABBlockReader.h"
#import "XADException.h"

@implementation XADCABBlockReader

-(id)initWithHandle:(CSHandle *)handle reservedBytes:(int)reserved
{
	if((self=[super init]))
	{
		parent=[handle retain];
		extbytes=reserved;
		numfolders=0;
	}
	return self;
}

-(void)dealloc
{
	[parent release];
	[super dealloc];
}



-(void)addFolderAtOffset:(off_t)startoffs numberOfBlocks:(int)num
{
	if(numfolders==sizeof(offsets)/sizeof(offsets[0])) [XADException raiseNotSupportedException];

	offsets[numfolders]=startoffs;
	numblocks[numfolders]=num;
	numfolders++;
}

-(void)scanLengths
{
	complen=0;
	uncomplen=0;

	for(int folder=0;folder<numfolders;folder++)
	{
		[parent seekToFileOffset:offsets[folder]];

		for(int block=0;block<numblocks[folder];block++)
		{
			/*uint32_t check=*/[parent readUInt32LE];
			int compbytes=[parent readUInt16LE];
			int uncompbytes=[parent readUInt16LE];
			[parent skipBytes:extbytes+compbytes];

			complen+=compbytes;
			uncomplen+=uncompbytes;
		}
	}
}



-(CSHandle *)handle { return parent; }

-(off_t)compressedLength { return complen; }

-(off_t)uncompressedLength { return uncomplen; }

-(void)restart
{
	[parent seekToFileOffset:offsets[0]];
	currentfolder=0;
	currentblock=0;
}

-(BOOL)readNextBlockToBuffer:(uint8_t *)buffer compressedLength:(int *)compptr
uncompressedLength:(int *)uncompptr
{
	if(currentfolder>=numfolders) [XADException raiseDecrunchException];

	/*uint32_t check=*/[parent readUInt32LE];
	int compbytes=[parent readUInt16LE];
	int uncompbytes=[parent readUInt16LE];
	[parent skipBytes:extbytes];

	if(compbytes>32768+6144) [XADException raiseIllegalDataException];

	[parent readBytes:compbytes toBuffer:buffer];

	int totalbytes=compbytes;
	while(uncompbytes==0)
	{
		currentblock=0;
		currentfolder++;

		if(currentfolder>=numfolders) [XADException raiseIllegalDataException];

		[parent seekToFileOffset:offsets[currentfolder]];
		/*check=*/[parent readUInt32LE];
		compbytes=[parent readUInt16LE];
		uncompbytes=[parent readUInt16LE];
		[parent skipBytes:extbytes];

		if(compbytes+totalbytes>32768+6144) [XADException raiseIllegalDataException];

		[parent readBytes:compbytes toBuffer:&buffer[totalbytes]];
		totalbytes+=compbytes;
	}

	currentblock++;
	if(currentblock>=numblocks[currentfolder])
	{
		// Can this happen? Not sure, supporting it anyway.
		currentblock=0;
		currentfolder++;
		[parent seekToFileOffset:offsets[currentfolder]];
	}

	if(compptr) *compptr=totalbytes;
	if(uncompptr) *uncompptr=uncompbytes;

	return currentfolder>=numfolders;
}

@end
