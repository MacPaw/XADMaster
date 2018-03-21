/*
 * XADRAR15Handle.h
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
#import "XADFastLZSSHandle.h"
#import "XADRARParser.h"
#import "XADPrefixCode.h"

@interface XADRAR15Handle:XADFastLZSSHandle
{
	XADRARParser *parser;

	NSArray *files;
	int file;
	off_t endpos;

	XADPrefixCode *lengthcode1,*lengthcode2;
	XADPrefixCode *huffmancode0,*huffmancode1,*huffmancode2,*huffmancode3,*huffmancode4;
	XADPrefixCode *shortmatchcode0,*shortmatchcode1,*shortmatchcode2,*shortmatchcode3;

	BOOL storedblock;

	unsigned int flags,flagbits;
	unsigned int literalweight,matchweight;
	unsigned int numrepeatedliterals,numrepeatedlastmatches;
	unsigned int runningaverageliteral,runningaverageselector;
	unsigned int runningaveragelength,runningaverageoffset,runningaveragebelowmaximum;
	unsigned int maximumoffset;
	BOOL bugfixflag;

	int lastoffset,lastlength;
	int oldoffset[4],oldoffsetindex;

	int flagtable[256],flagreverse[256];
	int literaltable[256],literalreverse[256];
	int offsettable[256],offsetreverse[256];
	int shortoffsettable[256];
}

-(id)initWithRARParser:(XADRARParser *)parentparser files:(NSArray *)filearray;
-(void)dealloc;

-(void)resetLZSSHandle;
-(void)startNextFile;
-(void)expandFromPosition:(off_t)pos;

@end
