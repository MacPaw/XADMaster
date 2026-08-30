/*
 * XADCFBFParser.m
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
#import "XADCFBFParser.h"
#import "XADBlockHandle.h"
#import "NSDateXAD.h"
#import <limits.h>

static const int kCFBFEntryNameMaxSize = 64;

@implementation XADCFBFParser

-(id)init
{
	if((self=[super init]))
	{
		sectable=NULL;
		minisectable=NULL;
		secvisitedtable=NULL;
	}
	return self;
}

-(void)dealloc
{
	free(sectable);
	free(minisectable);
	free(secvisitedtable);
	[super dealloc];
}

+(int)requiredHeaderSize { return 512; }

+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name
{
	const uint8_t *bytes=[data bytes];
	int length=[data length];

	return length>=512&&bytes[0]==0xd0&&bytes[1]==0xcf&&bytes[2]==0x11&&bytes[3]==0xe0&&
	bytes[4]==0xa1&&bytes[5]==0xb1&&bytes[6]==0x1a&&bytes[7]==0xe1&&bytes[28]==0xfe&&bytes[29]==0xff;
}

-(void)parse
{
	CSHandle *fh=[self handle];

	/* Read header */

	[fh skipBytes:30];
	int secshift=[fh readUInt16LE];
	int minisecshift=[fh readUInt16LE];
	[fh skipBytes:10];
	uint32_t numtablesecs=[fh readUInt32LE];
	uint32_t firstdirsec=[fh readUInt32LE];
	[fh skipBytes:4];
	minsize=[fh readUInt32LE];
	uint32_t firstminitablesec=[fh readUInt32LE];
	uint32_t numminitablesecs=[fh readUInt32LE];
	uint32_t firstmastersec=[fh readUInt32LE];
	/*uint32_t nummastersecs=*/[fh readUInt32LE];

	const int maxSecShift=(int)(sizeof(secsize)*CHAR_BIT)-1;
	const int maxMiniSecShift=(int)(sizeof(minisecsize)*CHAR_BIT)-1;
	if(secshift>=maxSecShift || minisecshift>=maxMiniSecShift)
	{
		[XADException raiseIllegalDataException];
	}

	// Shift values are validated above to prevent overflow.
	secsize=1<<secshift;
	minisecsize=1<<minisecshift;

	/* Read allocation table through the master allocation table */

	int idspersec=secsize/4;
	// Per MS-CFB spec, Sector Shift MUST be 0x0009 (version 3) or 0x000C (version 4),
	// giving idspersec of 128 or 1024. We do not enforce spec values to preserve
	// compatibility with non-conformant files. However, idspersec==0 (secsize<4)
	// and idspersec==1 (secsize==4) must be rejected: the DIFAT traversal below
	// uses (idspersec-1) as a modulo divisor, which would be zero in those cases.
	if(idspersec<=1)
	{
		[XADException raiseIllegalDataException];
	}

	// numtablesecs*idspersec must not overflow int.
	// numtablesecs==0 means no FAT sectors, which is invalid.
	if(numtablesecs==0 || numtablesecs>(uint32_t)(INT_MAX/idspersec))
	{
		[XADException raiseIllegalDataException];
	}
	numsectors=(int)(numtablesecs*(uint32_t)idspersec);
	// numsectors*sizeof(uint32_t) must not overflow size_t.
	if((size_t)numsectors>SIZE_MAX/sizeof(uint32_t))
	{
		[XADException raiseIllegalDataException];
	}
	sectable=malloc((size_t)numsectors*sizeof(uint32_t));
	if(!sectable)
	{
		[XADException raiseOutOfMemoryException];
	}
	secvisitedtable=calloc(numsectors,sizeof(bool));
	if(!secvisitedtable)
	{
		[XADException raiseOutOfMemoryException];
	}

	for(int i=0;i<numtablesecs;i++)
	{
		if(i==109)
		{
			[self seekToSector:firstmastersec];
		}
		else if(i>109 && (i-109)%(idspersec-1)==0)
		{
			uint32_t nextsec=[fh readUInt32LE];
			[self seekToSector:nextsec];
		}

		int sector=[fh readUInt32LE];
		off_t currpos=[fh offsetInFile];

		[self seekToSector:sector];
		for(int j=0;j<idspersec;j++) sectable[i*idspersec+j]=[fh readUInt32LE];
		[fh seekToFileOffset:currpos];
	}

	/* Read short-sector allocation table */

	// numminitablesecs*idspersec must not overflow int.
	if(numminitablesecs>(uint32_t)(INT_MAX/idspersec))
	{
		[XADException raiseIllegalDataException];
	}
	numminisectors=(int)(numminitablesecs*(uint32_t)idspersec);
	// numminitablesecs==0 is valid for files with no mini-stream.
	// Skip allocation; malloc(0) may return NULL, which would be misidentified as OOM.
	if(numminisectors>0)
	{
		// numminisectors*sizeof(uint32_t) must not overflow size_t.
		if((size_t)numminisectors>SIZE_MAX/sizeof(uint32_t))
		{
			[XADException raiseIllegalDataException];
		}
		minisectable=malloc((size_t)numminisectors*sizeof(uint32_t));
		if(!minisectable)
		{
			[XADException raiseOutOfMemoryException];
		}
	}

	uint32_t minitablesec=firstminitablesec;
	for(int i=0;i<numminitablesecs;i++)
	{
		[self seekToSector:minitablesec];
		for(int j=0;j<idspersec;j++) minisectable[i*idspersec+j]=[fh readUInt32LE];
		minitablesec=[self nextSectorAfter:minitablesec];
	}

	/* Read directory entries */

	NSMutableArray *entries=[NSMutableArray array];

	BOOL firstentry=YES;
	uint32_t dirsec=firstdirsec;
	while(dirsec!=0xfffffffe)
	{
		// dirsec comes from the file and may exceed the secvisitedtable bounds.
		if(dirsec>=(uint32_t)numsectors) [XADException raiseIllegalDataException];
		if(secvisitedtable[dirsec]) [XADException raiseIllegalDataException];
		secvisitedtable[dirsec]=true;
		[self seekToSector:dirsec];
		for(int i=0;i<secsize;i+=128)
		{
			uint8_t name[kCFBFEntryNameMaxSize];
			[fh readBytes:kCFBFEntryNameMaxSize toBuffer:name];
			// The name field in a CFBF directory entry is always kCFBFEntryNameMaxSize bytes,
			// but the stored length may exceed this in malformed files.
			int numnamebytes=[self sanitizedNameLength:[fh readUInt16LE] fromBuffer:name];
			int type=[fh readUInt8];
			int black=[fh readUInt8];
			uint32_t leftchild=[fh readUInt32LE];
			uint32_t rightchild=[fh readUInt32LE];
			uint32_t rootnode=[fh readUInt32LE];
			[fh skipBytes:16];
			uint32_t flags=[fh readUInt32LE];
			uint64_t created=[fh readUInt64LE];
			uint64_t modified=[fh readUInt64LE];
			uint32_t firstsec=[fh readUInt32LE];

			off_t size;
			if(secshift>=12)
			{
				size=[fh readUInt64LE];
			}
			else
			{
				size=[fh readUInt32LE];
				[fh skipBytes:4];
			}

			if(firstentry)
			{
				if(type!=5 && type!=0) [XADException raiseIllegalDataException];
				firstentry=NO;
			}

			if(type==0) // empty entry
			{
				[entries addObject:[NSNull null]];
			}
			else if(type==5) // root entry
			{
				rootdirectorynode=rootnode;
				firstminisector=firstsec;

				[entries addObject:[NSNull null]];
			}
			else
			{
				NSMutableDictionary *entry=[NSMutableDictionary dictionaryWithObjectsAndKeys:
					[self decodeFileNameWithBytes:name length:numnamebytes],@"CFBFFileName",
					[NSNumber numberWithInt:type],@"CFBFType",
					[NSNumber numberWithInt:black],@"CFBFRedOrBlack",
					[NSNumber numberWithUnsignedInt:leftchild],@"CFBFLeftChild",
					[NSNumber numberWithUnsignedInt:rightchild],@"CFBFRightChild",
					[NSNumber numberWithUnsignedInt:flags],@"CFBFFlags",
				nil];

				if(type==1)
				{
					[entry setObject:[NSNumber numberWithBool:YES] forKey:XADIsDirectoryKey];
					[entry setObject:[NSNumber numberWithUnsignedInt:rootnode] forKey:@"CFBFRootNode"];
				}
				else if(type==2)
				{
					[entry setObject:[NSNumber numberWithLongLong:size] forKey:XADFileSizeKey];
					[entry setObject:[NSNumber numberWithLongLong:size] forKey:XADCompressedSizeKey];
					[entry setObject:[NSNumber numberWithUnsignedLongLong:firstsec] forKey:@"CFBFFirstSector"];
				}

				if(created) [entry setObject:[NSDate XADDateWithWindowsFileTime:created] forKey:XADCreationDateKey];
				if(modified) [entry setObject:[NSDate XADDateWithWindowsFileTime:modified] forKey:XADLastModificationDateKey];

				[entries addObject:entry];
			}
		}
		dirsec=[self nextSectorAfter:dirsec];
	}

	/* Resolve directory structure */

	[self processEntry:rootdirectorynode atPath:[self XADPath] entries:entries];
}

-(XADString *)decodeFileNameWithBytes:(uint8_t *)bytes length:(int)length
{
	static const int LowChar=0x3800;
	static const int HighChar=0x3800+64*65;
	static const char Chars[64]="0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz._";

	for(int i=0;i<length-2;i+=2)
	{
		uint16_t c=CSUInt16LE(&bytes[i]);
		if(c<LowChar||c>HighChar)
		{
			NSMutableString *filename=[NSMutableString stringWithCapacity:length/2-2];
			for(int i=0;i<length-2;i+=2) [filename appendFormat:@"%C",CSUInt16LE(&bytes[i])];
			return [self XADStringWithString:filename];
		}
	}

	NSMutableString *filename=[NSMutableString stringWithCapacity:length];

	for(int i=0;i<length-2;i+=2)
	{
		uint16_t code=CSUInt16LE(&bytes[i])-LowChar;

		if(code==HighChar) [filename appendString:@"!"];
		else
		{
			int c1=code&0x3f;
			int c2=code>>6;

			[filename appendFormat:@"%c",Chars[c1]];
			if(c2<64) [filename appendFormat:@"%c",Chars[c2]];
		}
	}

	return [self XADStringWithString:filename];
}

-(void)processEntry:(uint32_t)n atPath:(XADPath *)path entries:(NSArray *)entries
{
	NSMutableDictionary *entry=[entries objectAtIndex:n];

	uint32_t left=[[entry objectForKey:@"CFBFLeftChild"] unsignedIntValue];
	if(left!=0xffffffff) [self processEntry:left atPath:path entries:entries];

	XADPath *filename=[path pathByAppendingXADStringComponent:[entry objectForKey:@"CFBFFileName"]];
	[entry setObject:filename forKey:XADFileNameKey];
	[self addEntryWithDictionary:entry];

	int type=[[entry objectForKey:@"CFBFType"] intValue];
	if(type==1)
	{
		uint32_t root=[[entry objectForKey:@"CFBFRootNode"] unsignedIntValue];
		if(root!=0xffffffff) [self processEntry:root atPath:filename entries:entries];
	}

	uint32_t right=[[entry objectForKey:@"CFBFRightChild"] unsignedIntValue];
	if(right!=0xffffffff) [self processEntry:right atPath:path entries:entries];
}

-(int)sanitizedNameLength:(int)numnamebytes fromBuffer:(const uint8_t *)bytes
{
	if(numnamebytes<=kCFBFEntryNameMaxSize) return numnamebytes;

	for(int i=0;i<=kCFBFEntryNameMaxSize-2;i+=2)
	{
		if(CSUInt16LE(&bytes[i])==0) return i+2;
	}

	[XADException raiseIllegalDataException];
	return 0; // unreachable
}

-(void)seekToSector:(uint32_t)sector
{
	if(sector>=numsectors) [XADException raiseIllegalDataException];
	[[self handle] seekToFileOffset:(sector+1)*secsize];
}

-(uint32_t)nextSectorAfter:(uint32_t)sector
{
	if(sector>=numsectors) [XADException raiseIllegalDataException];
	return sectable[sector];
}



-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum
{
	CSHandle *handle=[self handle];
	off_t size=[[dict objectForKey:XADFileSizeKey] longLongValue];
	uint32_t first=[[dict objectForKey:@"CFBFFirstSector"] unsignedIntValue];

	if(size>=minsize)
	{
		XADBlockHandle *bh=[[[XADBlockHandle alloc] initWithHandle:handle length:size blockSize:secsize] autorelease];
		[bh setBlockChain:sectable numberOfBlocks:numsectors firstBlock:first headerSize:512];

		return bh;
	}
	else
	{
		XADBlockHandle *bh=[[[XADBlockHandle alloc] initWithHandle:handle blockSize:secsize] autorelease];
		[bh setBlockChain:sectable numberOfBlocks:numsectors firstBlock:firstminisector headerSize:512];

		XADBlockHandle *mbh=[[[XADBlockHandle alloc] initWithHandle:bh length:size blockSize:minisecsize] autorelease];
		[mbh setBlockChain:minisectable numberOfBlocks:numminisectors firstBlock:first headerSize:0];

		return mbh;
	}
}

-(NSString *)formatName
{
	return @"CFBF";
}

@end
