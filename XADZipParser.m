/*
 * XADZipParser.m
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
#import "XADZipParser.h"
#import "XADZipImplodeHandle.h"
#import "XADZipShrinkHandle.h"
#import "XADDeflateHandle.h"
#import "XADLZMAHandle.h"
#import "XADPPMdHandles.h"
#import "XADZipCryptHandle.h"
#import "XADWinZipAESHandle.h"
#import "XADWinZipWavPackHandle.h"
#import "XADWinZipJPEGHandle.h"
#import "CSZlibHandle.h"
#import "CSBzip2Handle.h"
#import "XADCRCHandle.h"
#import "NSDateXAD.h"
#import "Scanning.h"

#import <sys/stat.h>




@implementation XADZipParser

+(int)requiredHeaderSize { return 8; }

+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name
{
	const uint8_t *bytes=[data bytes];
	int length=[data length];

	if(length<8) return NO;

	if(bytes[0]=='P'&&bytes[1]=='K'&&bytes[2]==3&&bytes[3]==4) return YES;
	if(bytes[0]=='P'&&bytes[1]=='K'&&bytes[2]==5&&bytes[3]==6) return YES;
	if(bytes[4]=='P'&&bytes[5]=='K'&&bytes[6]==3&&bytes[7]==4) return YES;

	return NO;
}

+(NSArray *)volumesForHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name
{
	NSArray *matches;

	// If the filename is of the type .z01, this is a multi-part archive
	// for sure, so scan for more parts. The final .zip part of multi-part
	// archives is handled by a subclass.
	if((matches=[name substringsCapturedByPattern:@"^(.*)\\.(z[0-9]{2})$" options:REG_ICASE]))
	{
		return [self scanForVolumesWithFilename:name
		regex:[XADRegex regexWithPattern:[NSString stringWithFormat:@"^%@\\.(zip|z[0-9]{2})$",
			[[matches objectAtIndex:1] escapedPattern]] options:REG_ICASE]
		firstFileExtension:@"z01"];
	}

	// In case the first part of a .zip.001 split file was detected as Zip,
	// scan for the other parts. If a later part was opened, XADSplitFileParser
	// will handle it instead.
	if((matches=[name substringsCapturedByPattern:@"^(.*)\\.[0-9]{3}$" options:REG_ICASE]))
	{
		return [self scanForVolumesWithFilename:name
		regex:[XADRegex regexWithPattern:[NSString stringWithFormat:@"^%@\\.[0-9]{3}$",
			[[matches objectAtIndex:1] escapedPattern]] options:REG_ICASE]
		firstFileExtension:nil];
	}

	// In case the first part of a .1.zip multi-part file was detected as Zip,
	// scan for the other parts.
	if((matches=[name substringsCapturedByPattern:@"^(.*)\\.1\\.zip$" options:REG_ICASE]))
	{
		return [self scanForVolumesWithFilename:name
		regex:[XADRegex regexWithPattern:[NSString stringWithFormat:@"^%@(\\.[0-9]+|())\\.zip$",
			[[matches objectAtIndex:1] escapedPattern]] options:REG_ICASE]
		firstFileExtension:nil];
	}

	return nil;
}



-(id)init
{
	if((self=[super init]))
	{
		prevdict=nil;
		prevname=nil;
	}
	return self;
}

-(void)dealloc
{
	[prevdict release];
	[prevname release];
	[super dealloc];
}

-(void)findCentralDirectoryRecordOffset:(off_t *)centrOffset zip64Offset:(off_t *)zip64offs
{
    // Default values
    if (centrOffset) *centrOffset=-1;
    if (zip64offs) *zip64offs=-1;

    CSHandle *fh=[self handle];
    [fh seekToEndOfFile];
    off_t end=[fh offsetInFile];

    // TODO: There should be another way of correctly searching signature for zip file
    // 1MB in memory is not always a good idea
    // This is a question whether Central Directory Record can be farther than this
    int chunkSize = 0x10000;
    off_t chunk_end = end;
    while (true) {

        // read n bytes or less, if this is the last chunk
        int numbytes=chunkSize;
        if(chunk_end - numbytes<0) numbytes=(int)chunk_end;
        off_t chunk_start = chunk_end - numbytes;

        uint8_t *buf = malloc(numbytes);
        [fh seekToFileOffset:chunk_start];
        [fh readBytes:numbytes toBuffer:buf];

        int preservedBytes = chunk_start >= 20 ? 20 : 0;
        int pos=numbytes-4;
        // Find end of central directory record
        while(pos>=preservedBytes)
        {
            if(buf[pos]=='P'&&buf[pos+1]=='K'&&buf[pos+2]==5&&buf[pos+3]==6) break;
            pos--;
        }

        BOOL centralOffsetFound = pos >= preservedBytes;
        if (centralOffsetFound) {
            if (centrOffset) {
                *centrOffset = chunk_start + pos;
            }

            // Found a zip64 end of central directory locator.
            if(pos>=20 && buf[pos-20]=='P' && buf[pos-19]=='K' && buf[pos-18]==6 && buf[pos-17]==7)
            {
                if (zip64offs) *zip64offs = chunk_start + pos - 20;
            }
        }
        free(buf);

        if (centralOffsetFound) {
            return;
        }

        // If chunk was exact at position of overlapping, we would likely to read next chunk a bit overlapped
        //         PK67   P
        //  |----------|----------| In basic reading syle, we can miss zip64Offset, beacuse it wil be in the next chunk
        //
        // Instead, we'll read chunks a bit overlapped
        // This will allow us to prevent cases when part is in another chunk
        //             |----------|
        //      |----------|

        chunk_end -= (chunkSize - preservedBytes * 2);

        if (chunk_end <= 0) {
            break;
        }
    }
}


-(void)parseWithSeparateMacForks
{
    off_t centraloffs = -1;
    off_t zip64offs = -1;
    [self findCentralDirectoryRecordOffset:&centraloffs zip64Offset:&zip64offs];

    CSHandle *fh=[self handle];
    [fh seekToEndOfFile];
    off_t end=[fh offsetInFile];

	if(centraloffs == -1)
	{
		// Could not find a central directory record. Scan the zip file from the start instead.
		[self parseWithoutCentralDirectory];
		return;
	}

	// Find zip64 end of central directory locator
	if(zip64offs != -1)
	{
		// Found a zip64 end of central directory locator.
		[self parseWithCentralDirectoryAtOffset:centraloffs zip64Offset:zip64offs];
	}
	else
	{
		// Could not find a zip64 end of central directory locator.
		if(end>0x100000000)
		{
			// If the file is larger than 4GB, this means some genius wrote a
			// 64-bit file without 64-bit extensions, and we have to just give up on the
			// central directory entirely.
			[self parseWithoutCentralDirectory];
		}
		else
		{
			// If the file is small enough, everything is fine, and we continue.
			[self parseWithCentralDirectoryAtOffset:centraloffs zip64Offset:-1];
		}
	}
}





-(void)parseWithCentralDirectoryAtOffset:(off_t)centraloffs zip64Offset:(off_t)zip64offs
{
	CSHandle *fh=[self handle];

	[fh seekToFileOffset:centraloffs+4];

	/*uint32_t disknumber=*/[fh readUInt16LE];
	int centraldirstartdisk=[fh readUInt16LE];
	/*off_t numentriesdisk=*/[fh readUInt16LE];
	off_t numentries=[fh readUInt16LE];
	off_t centralsize=[fh readUInt32LE];
	off_t centraloffset=[fh readUInt32LE];
	int commentlength=[fh readUInt16LE];

	if(commentlength)
	{
		NSData *comment=[fh readDataOfLength:commentlength];
		[self setObject:[self XADStringWithData:comment] forPropertyKey:XADCommentKey];
	}

	if(zip64offs>=0)
	{
		// Read locator to find where the zip64 end of central directory record actually is.
		[fh seekToFileOffset:zip64offs+4];
		int disk=[fh readUInt32LE];
		off_t offs=[fh readUInt64LE];
		[fh seekToFileOffset:[self offsetForVolume:disk offset:offs]];

		uint32_t zip64id=[fh readID];
		if(zip64id==0x504b0606)
		{
			/*off_t recsize=*/[fh readUInt64LE];
			/*int version=*/[fh readUInt16LE];
			/*int extractversion=*/[fh readUInt16LE];
			/*uint32_t disknumber=*/[fh readUInt32LE];
			centraldirstartdisk=[fh readUInt32LE];
			/*off_t numentriesdisk=*/[fh readUInt64LE];
			numentries=[fh readUInt64LE];
			centralsize=[fh readUInt64LE];
			centraloffset=[fh readUInt64LE];
		}
	}

	// TODO: more closely check multi-archives
	//NSLog(@"disknumber:%d centraldirstartdisk:%d numentriesdisk:%qd numentries:%qd centralsize:%qd centraloffset:%qd",
	//disknumber,centraldirstartdisk,numentriesdisk,numentries,centralsize,centraloffset);

	[fh seekToFileOffset:[self offsetForVolume:centraldirstartdisk offset:centraloffset]];

	for(int i=0;i<numentries;i++)
	{
		if(![self shouldKeepParsing]) break;

		NSAutoreleasePool *pool=[NSAutoreleasePool new];

        XADZipParserCentralDirectoryRecord cdr = [self readCentralDirectoryRecord];

        // Parse comment data
		NSData *commentdata=nil;
		if(cdr.commentlength) commentdata=[fh readDataOfLength:cdr.commentlength];
        
		off_t next=[fh offsetInFile];

		// Some idiotic compressors write files with more than 65535 files without
		// using Zip64, so numentries overflows. Try to detect if there is enough space
		// left in the central directory for another 65536 files, and if so, extend the
		// parsing to include them. This may happen multiple times.
		if(i==numentries-1 && zip64offs<0)
		{
			if(centraloffset+centralsize-next>65536*46) numentries+=65536;
		}

		// Read local header
		[fh seekToFileOffset:[self offsetForVolume:cdr.startdisk offset:cdr.locheaderoffset]];

		uint32_t localid=[fh readID];
		if(localid==0x504b0304||localid==0x504b0506) // kludge for strange archives
		{
			//int localextractversion=[fh readUInt16LE];
			//int localflags=[fh readUInt16LE];
			//int localcompressionmethod=[fh readUInt16LE];
			[fh skipBytes:6];
			uint32_t localdate=[fh readUInt32LE];
			//uint32_t localcrc=[fh readUInt32LE];
			//uint32_t localcompsize=[fh readUInt32LE];
			//uint32_t localuncompsize=[fh readUInt32LE];
			[fh skipBytes:12];
			int localnamelength=[fh readUInt16LE];
			int localextralength=[fh readUInt16LE];

			off_t dataoffset=[fh offsetInFile]+localnamelength+localextralength;

			NSData *namedata=nil;
			if(localnamelength) namedata=[fh readDataOfLength:localnamelength];

			NSDictionary *extradict=nil;
			@try {
				if(localextralength) extradict=[self parseZipExtraWithLength:localextralength nameData:namedata
				uncompressedSizePointer:&cdr.uncompsize compressedSizePointer:&cdr.compsize];
			} @catch(id e) {
				[self setObject:[NSNumber numberWithBool:YES] forPropertyKey:XADIsCorruptedKey];
				NSLog(@"Error parsing Zip extra fields: %@",e);
			}

            // TODO: Consider using CDR struct
			[self addZipEntryWithSystem:cdr.system extractVersion:cdr.extractversion flags:cdr.flags
			compressionMethod:cdr.compressionmethod date:cdr.date crc:cdr.crc localDate:localdate
			compressedSize:cdr.compsize uncompressedSize:cdr.uncompsize extendedFileAttributes:cdr.extfileattrib
			extraDictionary:extradict dataOffset:dataoffset nameData:namedata commentData:commentdata
			isLastEntry:i==numentries-1];
		}
		else [self setObject:[NSNumber numberWithBool:YES] forPropertyKey:XADIsCorruptedKey];

		[fh seekToFileOffset:next];

		[pool release];
	}
}

-(XADZipParserCentralDirectoryRecord)readCentralDirectoryRecord
{
    CSHandle *fh=[self handle];

    XADZipParserCentralDirectoryRecord cdr;
    // Read central directory record.
    cdr.centralid=[fh readID];
    if(cdr.centralid!=0x504b0102) [XADException raiseIllegalDataException]; // could try recovering here

    cdr.creatorversion=[fh readUInt8];
    cdr.system=[fh readUInt8];
    cdr.extractversion=[fh readUInt16LE];
    cdr.flags=[fh readUInt16LE];
    cdr.compressionmethod=[fh readUInt16LE];
    cdr.date=[fh readUInt32LE];
    cdr.crc=[fh readUInt32LE];
    cdr.compsize=[fh readUInt32LE];
    cdr.uncompsize=[fh readUInt32LE];
    cdr.namelength=[fh readUInt16LE];
    cdr.extralength=[fh readUInt16LE];
    cdr.commentlength=[fh readUInt16LE];
    cdr.startdisk=[fh readUInt16LE];
    cdr.infileattrib=[fh readUInt16LE];
    cdr.extfileattrib=[fh readUInt32LE];
    cdr.locheaderoffset=[fh readUInt32LE];

    [fh skipBytes:cdr.namelength];

    // Read central directory extra fields, just to find the Zip64 field.
    int length=cdr.extralength;
    while(length>=8)
    {
        int extid=[fh readUInt16LE];
        int size=[fh readUInt16LE];
        length-=4;

        if(size>length) break;
        length-=size;
        off_t nextextra=[fh offsetInFile]+size;

        if(extid==1)
        {
            //
            // From https://pkware.cachefly.net/webdocs/casestudies/APPNOTE.TXT
            //
            // 4.5.3 -Zip64 Extended Information Extra Field (0x0001):
            // ... fields MUST only appear if the corresponding Local or Central directory record field is set to 0xFFFF or 0xFFFFFFFF.
            //
            // This means the ZIP64 fields must only appear if they're set to set to 0xFFFF or 0xFFFFFFFF in the Local/Central records.
            // Always reading them might result in a crash and a parse failure, even if the headers are correct.
            //
            if(cdr.uncompsize==0xffffffff) {
                cdr.uncompsize=[fh readUInt64LE];
            }
            if(cdr.compsize==0xffffffff) {
                cdr.compsize=[fh readUInt64LE];
            }
            if(cdr.locheaderoffset==0xffffffff) {
                cdr.locheaderoffset=[fh readUInt64LE];
            }
            if(cdr.startdisk==0xffff) {
                cdr.startdisk=[fh readUInt32LE];
            }
            //
            // We can't break since not always all fields are present so we need to seek to the next extra.
            // Investigated here: https://github.com/aonez/Keka/issues/423
            //
            //break;
            //
        }
        [fh seekToFileOffset:nextextra];
    }
    if(length) [fh skipBytes:length];
    return cdr;
}

-(off_t)offsetForVolume:(int)disk offset:(off_t)offset
{
	NSArray *sizes=[self volumeSizes];
	NSInteger count=[sizes count];

	for(NSInteger i=0;i<count && i<disk;i++) offset+=[[sizes objectAtIndex:i] longLongValue];

	return offset;
}

-(void)parseWithoutCentralDirectory
{
	CSHandle *fh=[self handle];

	[fh seekToFileOffset:0];

	while([self shouldKeepParsing])
	{
		NSAutoreleasePool *pool=[NSAutoreleasePool new];

		uint32_t localid;
		@try { localid=[fh readID]; }
		@catch(id e) { break; }

		switch(localid)
		{
			case 0x504b0304: // local record
			case 0x504b0506: // kludge for strange archives
			{
				int extractversion=[fh readUInt16LE];
				int flags=[fh readUInt16LE];
				int compressionmethod=[fh readUInt16LE];
				uint32_t date=[fh readUInt32LE];
				uint32_t crc=[fh readUInt32LE];
				off_t compsize=[fh readUInt32LE];
				off_t uncompsize=[fh readUInt32LE];
				int namelength=[fh readUInt16LE];
				int extralength=[fh readUInt16LE];

				off_t dataoffset=[fh offsetInFile]+namelength+extralength;

				NSData *namedata=nil;
				if(namelength) namedata=[fh readDataOfLength:namelength];

				NSDictionary *extradict=nil;
				@try {
					if(extralength) extradict=[self parseZipExtraWithLength:extralength nameData:namedata
					uncompressedSizePointer:&uncompsize compressedSizePointer:&compsize];
				} @catch(id e) {
					[self setObject:[NSNumber numberWithBool:YES] forPropertyKey:XADIsCorruptedKey];
					NSLog(@"Error parsing Zip extra fields: %@",e);
				}

				off_t next;
				if(flags&0x08) // No size or CRC recorded
				{
					NSNumber *zip64num=[extradict objectForKey:@"Zip64"];

					[self findEndOfStreamMarkerWithZip64Flag:zip64num&&[zip64num boolValue]
					uncompressedSizePointer:&uncompsize compressedSizePointer:&compsize
					CRCPointer:&crc];

					next=[fh offsetInFile];
				}
				else
				{
					next=dataoffset+compsize;
				}

				[self addZipEntryWithSystem:-1 extractVersion:extractversion flags:flags
				compressionMethod:compressionmethod date:date crc:crc localDate:date
				compressedSize:compsize uncompressedSize:uncompsize extendedFileAttributes:0xffffffff
				extraDictionary:extradict dataOffset:dataoffset nameData:namedata commentData:nil
				isLastEntry:NO];

				[fh seekToFileOffset:next];
			}
			break;

			case 0x504b0102: // central record - stop scanning
				[pool release];
				goto end;
			break;

			case 0x504b0708: // multi
			case 0x504b3030: // something strange
				// Skip these mysterious entries
				[self findNextEntry];
			break;

			default:
				// When encountering unknown data, mark as corrupt and try to recover
				[self setObject:[NSNumber numberWithBool:YES] forPropertyKey:XADIsCorruptedKey];
				[self findNextEntry];
			break;
		}

		[pool release];
	}

	end:

	// Clean up any possible remaining dictionary, since isLastEntry was never set.
	if(prevdict)
	{
		[self addRemeberedEntryAndForget];
	}
}



static int MatchZipDataDescriptor(const uint8_t *bytes,int available,off_t offset,void *state)
{
	if(available<12) return 0;

	if(available>=16)
	{
		if(bytes[0]=='P'&&bytes[1]=='K'&&bytes[2]==7&&bytes[3]==8
		&&bytes[8]==(offset&0xff)
		&&bytes[9]==((offset>>8)&0xff)
		&&bytes[10]==((offset>>16)&0xff)
		&&bytes[11]==((offset>>24)&0xff))
		{
			if(available<18) return 2;
			if(bytes[16]=='P'&&bytes[17]=='K') return 2;
		}
	}

	if(bytes[4]==(offset&0xff)
	&&bytes[5]==((offset>>8)&0xff)
	&&bytes[6]==((offset>>16)&0xff)
	&&bytes[7]==((offset>>24)&0xff))
	{
		if(available<14) return 1;
		if(bytes[12]=='P'&&bytes[13]=='K') return 1;
	}

	return 0;
}

static int MatchZip64DataDescriptor(const uint8_t *bytes,int available,off_t offset,void *state)
{
	if(available<20) return 0;

	if(available>=24)
	{
		if(bytes[0]=='P'&&bytes[1]=='K'&&bytes[2]==7&&bytes[3]==8
		&&bytes[8]==(offset&0xff)
		&&bytes[9]==((offset>>8)&0xff)
		&&bytes[10]==((offset>>16)&0xff)
		&&bytes[11]==((offset>>24)&0xff)
		&&bytes[12]==((offset>>32)&0xff)
		&&bytes[13]==((offset>>40)&0xff)
		&&bytes[14]==((offset>>48)&0xff)
		&&bytes[15]==((offset>>56)&0xff))
		{
			if(available<26) return 2;
			if(bytes[24]=='P'&&bytes[25]=='K') return 2;
		}
	}

	if(bytes[4]==(offset&0xff)
	&&bytes[5]==((offset>>8)&0xff)
	&&bytes[6]==((offset>>16)&0xff)
	&&bytes[7]==((offset>>24)&0xff)
	&&bytes[8]==((offset>>32)&0xff)
	&&bytes[9]==((offset>>40)&0xff)
	&&bytes[10]==((offset>>48)&0xff)
	&&bytes[11]==((offset>>56)&0xff))
	{
		if(available<22) return 1;
		if(bytes[20]=='P'&&bytes[21]=='K') return 1;
	}

	return NO;
}

-(void)findEndOfStreamMarkerWithZip64Flag:(BOOL)zip64 uncompressedSizePointer:(off_t *)uncompsizeptr
compressedSizePointer:(off_t *)compsizeptr CRCPointer:(uint32_t *)crcptr
{
	CSHandle *fh=[self handle];

	if(zip64)
	{
		int type=[fh scanUsingMatchingFunction:MatchZip64DataDescriptor maximumLength:26];
		if(type==0) [XADException raiseIllegalDataException];
		if(type==2) [fh skipBytes:4];

		if(crcptr) *crcptr=[fh readUInt32LE];
		if(compsizeptr) *compsizeptr=[fh readUInt64LE];
		if(uncompsizeptr) *uncompsizeptr=[fh readUInt64LE];
	}
	else
	{
		int type=[fh scanUsingMatchingFunction:MatchZipDataDescriptor maximumLength:18];
		if(type==0) [XADException raiseIllegalDataException];
		if(type==2) [fh skipBytes:4];

		if(crcptr) *crcptr=[fh readUInt32LE];
		if(compsizeptr) *compsizeptr=[fh readUInt32LE];
		if(uncompsizeptr) *uncompsizeptr=[fh readUInt32LE];
	}
}




static int MatchZipEntry(const uint8_t *bytes,int available,off_t offset,void *state)
{
	if(available<6) return NO;

	if(bytes[0]!='P'||bytes[1]!='K'||bytes[5]!=0) return NO;
	if(bytes[2]==1&&bytes[3]==2) return YES;
	if(bytes[2]==3&&bytes[3]==4) return YES;
	if(bytes[2]==5&&bytes[3]==6) return YES;

	return NO;
}

-(void)findNextEntry
{
	[[self handle] scanUsingMatchingFunction:MatchZipEntry maximumLength:4];
}




-(NSDictionary *)parseZipExtraWithLength:(int)length nameData:(NSData *)namedata
uncompressedSizePointer:(off_t *)uncompsizeptr compressedSizePointer:(off_t *)compsizeptr
{
	CSHandle *fh=[self handle];
	NSMutableDictionary *dict=[NSMutableDictionary dictionary];

	off_t end=[fh offsetInFile]+length;

	while(length>=9)
	{
		int extid=[fh readUInt16LE];
		int size=[fh readUInt16LE];
		length-=4;

		if(size>length) break;
		length-=size;
		off_t next=[fh offsetInFile]+size;

		if(extid==1&&compsizeptr&&uncompsizeptr) // Zip64 extended information extra field
		{
			[dict setObject:[NSNumber numberWithBool:YES] forKey:@"Zip64"];
			if(*uncompsizeptr==0xffffffff) *uncompsizeptr=[fh readUInt64LE];
			if(*compsizeptr==0xffffffff) *compsizeptr=[fh readUInt64LE];
		}
		else if(extid==0x5455&&size>=5) // Extended Timestamp Extra Field
		{
            // https://opensource.apple.com/source/zip/zip-6/unzip/unzip/proginfo/extra.fld
			int flags=[fh readUInt8];
			if(flags&1) [dict setObject:[NSDate dateWithTimeIntervalSince1970:[fh readUInt32LE]] forKey:XADLastModificationDateKey];
			if(flags&2) [dict setObject:[NSDate dateWithTimeIntervalSince1970:[fh readUInt32LE]] forKey:XADLastAccessDateKey];
			if(flags&4) [dict setObject:[NSDate dateWithTimeIntervalSince1970:[fh readUInt32LE]] forKey:XADCreationDateKey];
		}
		else if(extid==0x5855&&size>=8) // Info-ZIP Unix Extra Field (type 1)
		{
			[dict setObject:[NSDate dateWithTimeIntervalSince1970:[fh readUInt32LE]] forKey:XADLastAccessDateKey];
			[dict setObject:[NSDate dateWithTimeIntervalSince1970:[fh readUInt32LE]] forKey:XADLastModificationDateKey];
			if(size>=10) [dict setObject:[NSNumber numberWithInt:[fh readUInt16LE]] forKey:XADPosixUserKey];
			if(size>=12) [dict setObject:[NSNumber numberWithInt:[fh readUInt16LE]] forKey:XADPosixGroupKey];
		}
		else if(extid==0x7855&&size>=8) // Info-ZIP Unix Extra Field (type 2)
		{
			[dict setObject:[NSNumber numberWithInt:[fh readUInt16LE]] forKey:XADPosixUserKey];
			[dict setObject:[NSNumber numberWithInt:[fh readUInt16LE]] forKey:XADPosixGroupKey];
		}
		else if(extid==0x7875&&size>=8) // Info-ZIP New Unix Extra Field (type 3)
		{
			int version=[fh readUInt8];
			if(version==1)
			{
				int uidsize=[fh readUInt8];
				if(uidsize==2) [dict setObject:[NSNumber numberWithInt:[fh readUInt16LE]] forKey:XADPosixUserKey];
				else if(uidsize==4) [dict setObject:[NSNumber numberWithUnsignedInt:[fh readUInt32LE]] forKey:XADPosixUserKey];
				else if(uidsize==8) [dict setObject:[NSNumber numberWithUnsignedLongLong:[fh readUInt64LE]] forKey:XADPosixUserKey];
				else [fh skipBytes:uidsize];

				int gidsize=[fh readUInt8];
				if(gidsize==2) [dict setObject:[NSNumber numberWithInt:[fh readUInt16LE]] forKey:XADPosixGroupKey];
				else if(gidsize==4) [dict setObject:[NSNumber numberWithUnsignedInt:[fh readUInt32LE]] forKey:XADPosixGroupKey];
				else if(gidsize==8) [dict setObject:[NSNumber numberWithUnsignedLongLong:[fh readUInt64LE]] forKey:XADPosixGroupKey];
				else [fh skipBytes:gidsize];
			}
		}
		else if(extid==0x334d&&size>=14) // Info-ZIP Macintosh Extra Field
		{
			int len=[fh readUInt32LE];
			int flags=[fh readUInt16LE];
			[dict setObject:[NSNumber numberWithUnsignedInt:[fh readID]] forKey:XADFileTypeKey];
			[dict setObject:[NSNumber numberWithUnsignedInt:[fh readID]] forKey:XADFileCreatorKey];

			CSHandle *mh=nil;
			if(flags&0x04) mh=fh; // uncompressed
			else
			{
				int ctype=[fh readUInt16LE];
				[fh skipBytes:4]; // skip CRC
				mh=[self decompressionHandleWithHandle:fh method:ctype flags:0 size:len];
			}
			if(mh&&len>=26)
			{
				[dict setObject:[NSNumber numberWithUnsignedInt:[mh readUInt16LE]] forKey:XADFinderFlagsKey];
				[mh skipBytes:24];

				off_t create,modify,backup;

				if(flags&0x08)
				{
					create=[mh readUInt64LE];
					modify=[mh readUInt64LE];
					backup=[mh readUInt64LE];
				}
				else
				{
					create=[mh readUInt32LE];
					modify=[mh readUInt32LE];
					backup=[mh readUInt32LE];
				}

				if(!(flags&0x10))
				{
					create+=[mh readInt32LE];
					modify+=[mh readInt32LE];
					backup+=[mh readInt32LE];
				}

				if(create>=86400) [dict setObject:[NSDate XADDateWithTimeIntervalSince1904:create] forKey:XADCreationDateKey];
				if(modify>=86400) [dict setObject:[NSDate XADDateWithTimeIntervalSince1904:modify] forKey:XADLastModificationDateKey];
				if(backup>=86400) [dict setObject:[NSDate XADDateWithTimeIntervalSince1904:backup] forKey:@"MacOSBackupDate"];
			}
		}
		else if(extid==0x2605&&size>=13) // ZipIt Macintosh Extra Field (long)
		{
			// ZipIt structure - the presence of it indicates the file is MacBinary encoded,
			// IF it is a file and not directory. Ignore information in this and rely on the
			// data stored in the MacBinary file instead, and mark the file.
			if(!([dict objectForKey:XADIsDirectoryKey]&&[[dict objectForKey:XADIsDirectoryKey] boolValue]))
			{
				if([fh readID]=='ZPIT') [dict setObject:[NSNumber numberWithBool:YES] forKey:XADIsMacBinaryKey];
			}
		}
		else if(extid==0x2705&&size>=12) // ZipIt Macintosh Extra Field (short, for files)
		{
			if([fh readID]=='ZPIT')
			{
				[dict setObject:[NSNumber numberWithUnsignedInt:[fh readID]] forKey:XADFileTypeKey];
				[dict setObject:[NSNumber numberWithUnsignedInt:[fh readID]] forKey:XADFileCreatorKey];
				if(size>=14) [dict setObject:[NSNumber numberWithUnsignedInt:[fh readUInt16BE]] forKey:XADFinderFlagsKey];
			}
		}
		else if(extid==0x2805&&size>=6) // ZipIt Macintosh Extra Field (short, for directories)
		{
			if([fh readID]=='ZPIT')
			{
				[dict setObject:[NSNumber numberWithUnsignedInt:[fh readUInt16BE]] forKey:XADFinderFlagsKey];
			}
		}
		else if(extid==0x7075&&size>=6) // Unicode Path Extra Field
		{
			int version=[fh readUInt8];
			if(version==1)
			{
				uint32_t crc=[fh readUInt32LE];
				NSData *unicodedata=[fh readDataOfLength:size-5];

				// Some archivers append garbage zero bytes to the end of the name.
				// Remove them if necessary.
				const uint8_t *bytes=[unicodedata bytes];
				int length=size-5;
				if(length && bytes[length-1]==0)
				{
					while(length && bytes[length-1]==0) length--;
					unicodedata=[unicodedata subdataWithRange:NSMakeRange(0,length)];
				}

				if((XADCalculateCRC(0xffffffff,[namedata bytes],[namedata length],
				XADCRCTable_edb88320)^0xffffffff)==crc)
				{
					XADPath *oldname=[dict objectForKey:XADFileNameKey];
					XADPath *newname=[self XADPathWithData:unicodedata encodingName:XADUTF8StringEncodingName separators:XADEitherPathSeparator];
					if(oldname) [dict setObject:oldname forKey:@"ZipRegularFilename"];
					[dict setObject:newname forKey:XADFileNameKey];
					// Apparently at least some files use Windows path separators instead of the
					// usual Unix. Not sure what to expect here, so using both.
				}
			}
		}
		else if(extid==0x9901&&size>=7)
		{
			int version;
			[dict setObject:[NSNumber numberWithInt:version=[fh readUInt16LE]] forKey:@"WinZipAESVersion"];
			[dict setObject:[NSNumber numberWithInt:[fh readUInt16LE]] forKey:@"WinZipAESVendor"];
			[dict setObject:[NSNumber numberWithInt:[fh readUInt8]] forKey:@"WinZipAESKeySize"];
			[dict setObject:[NSNumber numberWithInt:[fh readUInt16LE]] forKey:@"WinZipAESCompressionMethod"];
		}
		else
		{
			//NSLog(@"unknown extension: %x %d %@",extid,size,[fh readDataOfLength:size]);
		}

		[fh seekToFileOffset:next];
	}

	[fh seekToFileOffset:end];

	return dict;
}




-(void)addZipEntryWithSystem:(int)system
extractVersion:(int)extractversion
flags:(int)flags
compressionMethod:(int)compressionmethod
date:(uint32_t)date
crc:(uint32_t)crc
localDate:(uint32_t)localdate
compressedSize:(off_t)compsize
uncompressedSize:(off_t)uncompsize
extendedFileAttributes:(uint32_t)extfileattrib
extraDictionary:(NSDictionary *)extradict
dataOffset:(off_t)dataoffset
nameData:(NSData *)namedata
commentData:(NSData *)commentdata
isLastEntry:(BOOL)islastentry
{
	NSMutableDictionary *dict=[NSMutableDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithInt:extractversion],@"ZipExtractVersion",
		[NSNumber numberWithInt:flags],@"ZipFlags",
		[NSNumber numberWithInt:compressionmethod],@"ZipCompressionMethod",
		[NSDate XADDateWithMSDOSDateTime:date],XADLastModificationDateKey,
		[NSNumber numberWithUnsignedInt:crc],@"ZipCRC32",
		[NSNumber numberWithUnsignedInt:localdate],@"ZipLocalDate",
		[NSNumber numberWithInt:extfileattrib],@"ZipFileAttributes",
		[NSNumber numberWithUnsignedLongLong:compsize],XADCompressedSizeKey,
		[NSNumber numberWithUnsignedLongLong:uncompsize],XADFileSizeKey,
		[NSNumber numberWithLongLong:dataoffset],XADDataOffsetKey,
		[NSNumber numberWithUnsignedLongLong:compsize],XADDataLengthKey,
	nil];
	if(flags&0x01) [dict setObject:[NSNumber numberWithBool:YES] forKey:XADIsEncryptedKey];

	if(system!=-1) [dict setObject:[NSNumber numberWithInt:system] forKey:@"ZipOS"];

	NSString *systemname=nil;
	switch(system)
	{
		case 0: systemname=@"MS-DOS"; break;
		case 1: systemname=@"Amiga"; break;
		case 2: systemname=@"OpenVMS"; break;
		case 3: systemname=@"Unix"; break;
		case 4: systemname=@"VM/CMS"; break;
		case 5: systemname=@"Atari ST"; break;
		case 6: systemname=@"OS/2 H.P.F.S."; break;
		case 7: systemname=@"Macintosh"; break;
		case 8: systemname=@"Z-System"; break;
		case 9: systemname=@"CP/M"; break;
		case 10: systemname=@"Windows NTFS"; break;
		case 11: systemname=@"MVS (OS/390 - Z/OS)"; break;
		case 12: systemname=@"VSE"; break;
		case 13: systemname=@"Acorn Risc"; break;
		case 14: systemname=@"VFAT"; break;
		case 15: systemname=@"alternate MVS"; break;
		case 16: systemname=@"BeOS"; break;
		case 17: systemname=@"Tandem"; break;
		case 18: systemname=@"OS/400"; break;
		case 19: systemname=@"OS X (Darwin)"; break;
	}
	if(systemname) [dict setObject:[self XADStringWithString:systemname] forKey:@"ZipOSName"];

	NSString *compressionname=nil;
	switch(compressionmethod)
	{
		case 0: compressionname=@"None"; break;
		case 1: compressionname=@"Shrink"; break;
		case 2: compressionname=@"Reduce 1"; break;
		case 3: compressionname=@"Reduce 2"; break;
		case 4: compressionname=@"Reduce 3"; break;
		case 5: compressionname=@"Reduce 4"; break;
		case 6: compressionname=@"Implode"; break;
		case 8: compressionname=@"Deflate"; break;
		case 9: compressionname=@"Deflate64"; break;
		case 12: compressionname=@"Bzip2"; break;
		case 14: compressionname=@"LZMA"; break;
		case 96: compressionname=@"Compressed JPEG"; break;
		case 97: compressionname=@"WavPack"; break;
		case 98: compressionname=@"PPMd"; break;
	}
	if(compressionname) [dict setObject:[self XADStringWithString:compressionname] forKey:XADCompressionNameKey];

	if(compressionmethod==2||compressionmethod==3||compressionmethod==4||compressionmethod==5)
	[self reportInterestingFileWithReason:@"Reduce %d compression",compressionmethod-1];

	if(namedata)
	{
		const uint8_t *namebytes=[namedata bytes];
		int namelength=[namedata length];

		char *separators;
		if(system==0)
		{
			// Kludge: IZArc claims to be MS-DOS, and uses DOS path separators.
			// Allow DOS paths in this case, since files shouldn't contain
			// backslashes anyway.
			separators=XADEitherPathSeparator;
		}
		else
		{
			separators=XADUnixPathSeparator;
		}

		if(flags&0x800)
		[dict setObject:[self XADPathWithData:namedata encodingName:XADUTF8StringEncodingName separators:separators] forKey:XADFileNameKey];
		else
		[dict setObject:[self XADPathWithData:namedata separators:separators] forKey:XADFileNameKey];

		if(namebytes[namelength-1]=='/'&&uncompsize==0)
		[dict setObject:[NSNumber numberWithBool:YES] forKey:XADIsDirectoryKey];

		// If the previous entry was suspected of being a directory, check if the new
		// entry is a file inside it and set the directory flag for the previous one.
		if(prevdict)
		{
			const char *prevbytes=[prevname bytes];
			int prevlength=[prevname length];
			if(prevlength<namelength)
			{
				int i=0;
				while(namebytes[i]&&prevbytes[i]==namebytes[i]) i++;
				if(!prevbytes[i]&&namebytes[i]=='/')
				[prevdict setObject:[NSNumber numberWithBool:YES] forKey:XADIsDirectoryKey];
			}
		}

		// Check for possible MacBinary files
		if(namelength>4)
		{
			if(memcmp(namebytes+namelength-4,".bin",4)==0)
			[dict setObject:[NSNumber numberWithBool:YES] forKey:XADMightBeMacBinaryKey];
		}
	}
	else
	{
		[dict setObject:[self XADPathWithUnseparatedString:[[self name] stringByDeletingPathExtension]] forKey:XADFileNameKey];
		// TODO: set no filename flag
	}

	if(commentdata)
	{
		if(flags&0x800)
		[dict setObject:[self XADStringWithData:commentdata encodingName:XADUTF8StringEncodingName] forKey:XADCommentKey];
		else
		[dict setObject:[self XADStringWithData:commentdata] forKey:XADCommentKey];
	}

	if(extfileattrib!=0xffffffff)
	{
		if(system==0) // MS-DOS
		{
			if(extfileattrib&0x10 && compsize==0 && uncompsize==0) [dict setObject:[NSNumber numberWithBool:YES] forKey:XADIsDirectoryKey];
			[dict setObject:[NSNumber numberWithUnsignedInt:extfileattrib] forKey:XADDOSFileAttributesKey];

            // While the original system was MSDos, most novel archivers on those systems can still set valid permissions
            // For example, Archive created on windows, can still have valid symlinks in it
            int perm = extfileattrib >> 16;
            // Ignore permissions set to 0, as these are most likely writte by buggy archivers.

            // Ignore file permissions, because these can lead to the incorrect handling of the files on MacOS
            if (perm >= S_IFIFO) {
            	[dict setObject:[NSNumber numberWithInt:perm] forKey:XADPosixPermissionsKey];
            }

        }
		else if(system==1) // Amiga
		{
			[dict setObject:[NSNumber numberWithUnsignedInt:extfileattrib] forKey:XADAmigaProtectionBitsKey];
		}
		else if(system==3) // Unix
		{
			int perm=extfileattrib>>16;
			// Ignore permissions set to 0, as these are most likely writte by buggy archivers.
			if(perm!=0) [dict setObject:[NSNumber numberWithInt:perm] forKey:XADPosixPermissionsKey];
		}
	}

	#ifdef __APPLE__
	// Several amazingly broken archivers on OS X create files that do
	// not contain proper permissions. They still expect apps and scripts
	// to be executable, though, because Archive Utility by default makes
	// all files executable. Therefore, for files lacking permissions entries,
	// make up permissions based on the default mask.
	// This is only done on OS X.
	if(![dict objectForKey:XADPosixPermissionsKey])
	{
		mode_t mask=umask(0); umask(mask);
		[dict setObject:[NSNumber numberWithUnsignedShort:0777&~mask] forKey:XADPosixPermissionsKey];
	}
	#endif

	if(extradict) [dict addEntriesFromDictionary:extradict];

	if(prevdict)
	{
		[self addRemeberedEntryAndForget];
	}

	if(uncompsize==0&&!islastentry&&![dict objectForKey:XADIsDirectoryKey]&&namedata)
	{
		// this entry could be a directory, save it for testing against the next entry
		[self rememberEntry:dict withName:namedata];
	}
	else
	{
		[self addEntryWithDictionary:dict];
	}
}



-(void)rememberEntry:(NSMutableDictionary *)dict withName:(NSData *)namedata
{
	prevdict=[dict retain];
	prevname=[namedata retain];
}

-(void)addRemeberedEntryAndForget
{
	[self addEntryWithDictionary:prevdict];
	[prevdict release];
	[prevname release];
	prevdict=nil;
	prevname=nil;
}






-(CSHandle *)rawHandleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum
{
	CSHandle *fh=[self handleAtDataOffsetForDictionary:dict];

	int compressionmethod=[[dict objectForKey:@"ZipCompressionMethod"] intValue];
	int flags=[[dict objectForKey:@"ZipFlags"] intValue];
	off_t size=[[dict objectForKey:XADFileSizeKey] longLongValue];
	BOOL wrapchecksum=NO;

	NSNumber *enc=[dict objectForKey:XADIsEncryptedKey];
	if(enc && [enc boolValue])
	{
		off_t compsize=[[dict objectForKey:XADCompressedSizeKey] longLongValue];

		if(compressionmethod==99)
		{
			compressionmethod=[[dict objectForKey:@"WinZipAESCompressionMethod"] intValue];

			int version=[[dict objectForKey:@"WinZipAESVersion"] intValue];
			int vendor=[[dict objectForKey:@"WinZipAESVendor"] intValue];
			int keysize=[[dict objectForKey:@"WinZipAESKeySize"] intValue];
			if(version!=1&&version!=2) [XADException raiseNotSupportedException];
			if(vendor!=0x4541) [XADException raiseNotSupportedException];
			if(keysize<1||keysize>3) [XADException raiseNotSupportedException];

			int keybytes;
			switch(keysize)
			{
				case 1: keybytes=16; break;
				case 2: keybytes=24; break;
				case 3: keybytes=32; break;
			}

			if(version==2) wrapchecksum=YES;

			fh=[[[XADWinZipAESHandle alloc] initWithHandle:fh length:compsize
			password:[self encodedPassword] keyLength:keybytes] autorelease];
		}
		else
		{
			if(flags&0x40) [XADException raiseNotSupportedException];

			uint8_t test;
			if(flags&0x08) test=[[dict objectForKey:@"ZipLocalDate"] intValue]>>8;
			else test=[[dict objectForKey:@"ZipCRC32"] unsignedIntValue]>>24;

			fh=[[[XADZipCryptHandle alloc] initWithHandle:fh length:compsize
			password:[self encodedPassword] testByte:test] autorelease];
		}
	}

	CSHandle *handle=[self decompressionHandleWithHandle:fh method:compressionmethod flags:flags size:size];
	if(!handle) return nil;

	if(checksum)
	{
		if(wrapchecksum)
		{
			return [[[CSChecksumWrapperHandle alloc] initWithHandle:handle checksumHandle:fh] autorelease];
		}
		else
		{
			NSNumber *crc=[dict objectForKey:@"ZipCRC32"];
			return [XADCRCHandle IEEECRC32HandleWithHandle:handle
			length:[handle fileSize] correctCRC:[crc unsignedIntValue] conditioned:YES];
		}
	}

	return handle;
}

-(CSHandle *)decompressionHandleWithHandle:(CSHandle *)parent method:(int)method flags:(int)flags size:(off_t)size
{
	switch(method)
	{
		case 0: return parent;
		case 1: return [[[XADZipShrinkHandle alloc] initWithHandle:parent length:size] autorelease];
		case 6: return [[[XADZipImplodeHandle alloc] initWithHandle:parent length:size
						largeDictionary:flags&0x02 hasLiterals:flags&0x04] autorelease];
//		case 8: return [CSZlibHandle deflateHandleWithHandle:parent length:size];
		// Leave out length, because some archivers don't bother writing zip64
		// extensions for >4GB files, so size might be entirely wrong, and
		// archivers are expected to just keep unarchving anyway.
		case 8: return [CSZlibHandle deflateHandleWithHandle:parent];
//		case 8: return [[[XADDeflateHandle alloc] initWithHandle:parent length:size] autorelease];
		case 9: return [[[XADDeflateHandle alloc] initWithHandle:parent length:size variant:XADDeflate64DeflateVariant] autorelease];
		case 12: return [CSBzip2Handle bzip2HandleWithHandle:parent length:size];
		case 14:
		{
			[parent skipBytes:2];
			int len=[parent readUInt16LE];
			NSData *props=[parent readDataOfLength:len];
			return [[[XADLZMAHandle alloc] initWithHandle:parent length:size propertyData:props] autorelease];
		}
		break;
		case 96: return [[[XADWinZipJPEGHandle alloc] initWithHandle:parent length:size] autorelease];
		case 97: return [[[XADWinZipWavPackHandle alloc] initWithHandle:parent length:size] autorelease];
		case 98:
		{
			uint16_t info=[parent readUInt16LE];
			int maxorder=(info&0x0f)+1;
			int suballocsize=(((info>>4)&0xff)+1)<<20;
			int modelrestoration=info>>12;
			return [[[XADPPMdVariantIHandle alloc] initWithHandle:parent length:size
			maxOrder:maxorder subAllocSize:suballocsize modelRestorationMethod:modelrestoration] autorelease];
		}
		break;
		default:
			[self reportInterestingFileWithReason:@"Unsupported compression method %d",method];
			return nil;
	}
}

-(NSString *)formatName { return @"Zip"; }

@end

