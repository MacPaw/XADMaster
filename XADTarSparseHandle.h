/*
 * XADTarSparseHandle.h
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
#import "CSHandle.h"

typedef struct XADTarSparseRegion
{
	int nextRegion;
	off_t offset;
	off_t size;
	BOOL hasData;
	off_t dataOffset;
} XADTarSparseRegion;

@interface XADTarSparseHandle:CSHandle
{
	XADTarSparseRegion *regions;
	int numRegions;
	int currentRegion;
	off_t currentOffset;
	off_t realFileSize;
}

-(id)initWithHandle:(CSHandle *)handle size:(off_t)size;
-(id)initAsCopyOf:(XADTarSparseHandle *)other;
-(void)dealloc;

-(void)addSparseRegionFrom:(off_t)start length:(off_t)length;
-(void)addFinalSparseRegionEndingAt:(off_t)regionEndsAt;
-(void)setSingleEmptySparseRegion;

-(off_t)fileSize;
-(off_t)offsetInFile;
-(BOOL)atEndOfFile;

-(void)seekToFileOffset:(off_t)offs;
-(void)seekToEndOfFile;
-(int)readAtMost:(int)num toBuffer:(void *)buffer;

@end