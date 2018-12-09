/*
 * XADRAR30Handle.h
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
#import "XADRARParser.h"
#import "LZSS.h"
#import "XADPrefixCode.h"
#import "PPMd/VariantH.h"
#import "PPMd/SubAllocatorVariantH.h"
#import "XADRARVirtualMachine.h"

@interface XADRAR30Handle:CSBlockStreamHandle 
{
	XADRARParser *parser;

	NSArray *files;
	int file;
	off_t lastend;
	BOOL startnewfile,startnewtable;

	LZSS lzss;

	XADPrefixCode *maincode,*offsetcode,*lowoffsetcode,*lengthcode;

	int lastoffset,lastlength;
	int oldoffset[4];
	int lastlowoffset,numlowoffsetrepeats;

	BOOL ppmblock;
	PPMdModelVariantH ppmd;
	PPMdSubAllocatorVariantH *alloc;
	int ppmescape;

	XADRARVirtualMachine *vm;
	NSMutableArray *filtercode,*stack;
	off_t filterstart;
	int lastfilternum;
	int oldfilterlength[1024],usagecount[1024];
	off_t currfilestartpos;

	int lengthtable[299+60+17+28];
}

-(id)initWithRARParser:(XADRARParser *)parentparser files:(NSArray *)filearray;
-(void)dealloc;

-(void)resetBlockStream;
-(int)produceBlockAtOffset:(off_t)pos;
-(off_t)expandToPosition:(off_t)end;
-(void)allocAndParseCodes;

-(void)readFilterFromInput;
-(void)readFilterFromPPMd;
-(void)parseFilter:(const uint8_t *)bytes length:(int)length flags:(int)flags;
-(void)skipEmptyEntries;

@end
