/*
 * XADRAR50Handle.h
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
#import "XADRAR5Parser.h"
#import "LZSS.h"
#import "XADPrefixCode.h"
#import "PPMd/VariantH.h"
#import "PPMd/SubAllocatorVariantH.h"

@interface XADRAR50Handle:CSBlockStreamHandle
{
	XADRAR5Parser *parser;

	NSArray *files;
	int file;
	BOOL startnewfile;
	off_t currfilestartpos;

	off_t blockbitend;
	BOOL islastblock;

	LZSS lzss;

	XADPrefixCode *maincode,*offsetcode,*lowoffsetcode,*lengthcode;

	int lastlength;
	int oldoffset[4];
	int lastlowoffset,numlowoffsetrepeats;

	NSMutableArray *filters;
	NSMutableData *filterdata;

	int lengthtable[306+64+16+44];
}

-(id)initWithRARParser:(XADRAR5Parser *)parentparser files:(NSArray *)filearray;
-(void)dealloc;

-(void)resetBlockStream;
-(int)produceBlockAtOffset:(off_t)pos;
-(off_t)expandToPosition:(off_t)end;
-(void)readBlockHeader;
-(void)allocAndParseCodes;

@end
