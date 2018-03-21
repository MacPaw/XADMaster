/*
 * XADWinZipJPEGHandle.m
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
#import "XADWinZipJPEGHandle.h"
#import "XADException.h"

@implementation XADWinZipJPEGHandle

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length
{
	if((self=[super initWithInputBufferForHandle:handle length:length]))
	{
		decompressor=NULL;
	}
	return self;
}

-(void)dealloc
{
	FreeWinZipJPEGDecompressor(decompressor);
	[super dealloc];
}



static size_t ReadFunction(void *context,uint8_t *buffer,size_t length)
{
	CSInputBuffer *input=(CSInputBuffer *)context;
	for(int i=0;i<length;i++)
	{
		if(CSInputAtEOF(input)) return i;
		buffer[i]=CSInputNextByte(input);
	}
	return length;
}

-(void)resetBlockStream
{
	if(decompressor) FreeWinZipJPEGDecompressor(decompressor);

	decompressor=AllocWinZipJPEGDecompressor(ReadFunction,input);
	if(!decompressor) [XADException raiseExceptionWithXADError:XADOutOfMemoryError];

	int error=ReadWinZipJPEGHeader(decompressor);
	if(error)
	{
		fprintf(stderr,"Error %d while trying to read WinZip JPEG header.\n",error);
		[XADException raiseIllegalDataException];
	}
}

-(int)produceBlockAtOffset:(off_t)pos
{
	if(!AreMoreWinZipJPEGBytesAvailable(decompressor))
	{
		if(!AreMoreWinZipJPEGSlicesAvailable(decompressor))
		{
			int error=ReadNextWinZipJPEGBundle(decompressor);
			if(error)
			{
				fprintf(stderr,"Error %d while trying to read next WinZip JPEG bundle.\n",error);
				[XADException raiseIllegalDataException];
			}

			if(IsFinalWinZipJPEGBundle(decompressor)) [self endBlockStream];

			[self setBlockPointer:WinZipJPEGBundleMetadataBytes(decompressor)];
			return WinZipJPEGBundleMetadataLength(decompressor);
		}

		int error=ReadNextWinZipJPEGSlice(decompressor);
		if(error)
		{
			fprintf(stderr,"Error %d while trying to read next WinZip JPEG slice.\n",error);
			[XADException raiseExceptionWithXADError:XADInputError];
		}
	}

	size_t actual=EncodeWinZipJPEGBlocksToBuffer(decompressor,buffer,sizeof(buffer));
	[self setBlockPointer:buffer];

	return actual;
}

@end
