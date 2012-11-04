#import "XADStuffItParser.h"
#import "XADException.h"
#import "XADCRCHandle.h"
#import "NSDateXAD.h"

#import "XADStuffItHuffmanHandle.h"
#import "XADStuffItArsenicHandle.h"
#import "XADStuffIt13Handle.h"
#import "XADStuffItOldHandles.h"
#import "XADStuffItDESHandle.h"
#import "XADRLE90Handle.h"
#import "XADCompressHandle.h"
#import "XADLZHDynamicHandle.h"

// TODO: implement final bits of libxad's Stuffit.c

@implementation XADStuffItParser

+(int)requiredHeaderSize { return 22; }

+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name;
{
	const uint8_t *bytes=[data bytes];
	int length=[data length];

	if(length<14) return NO;

	if(CSUInt32BE(bytes+10)==0x724c6175)
	{
		if(CSUInt32BE(bytes)==0x53495421) return YES;
		// Installer archives?
		if(bytes[0]=='S'&&bytes[1]=='T')
		{
			if(bytes[2]=='i'&&(bytes[3]=='n'||(bytes[3]>='0'&&bytes[3]<='9'))) return YES;
			else if(bytes[2]>='0'&&bytes[2]<='9'&&bytes[3]>='0'&&bytes[3]<='9') return YES;
		}
	}
	return NO;
}

#define SITFH_COMPRMETHOD    0 /* xadUINT8 rsrc fork compression method */
#define SITFH_COMPDMETHOD    1 /* xadUINT8 data fork compression method */
#define SITFH_FNAMESIZE      2 /* xadUINT8 filename size */
#define SITFH_FNAME          3 /* xadUINT8 31 byte filename */
#define SITFH_FNAME_CRC     34 /* xadUINT16 crc of filename + size */

#define SITFH_UNK           36 /* xadUINT16 unknown, always 0x0986? */
#define SITFH_RSRCLONG      38 /* xadUINT32 unknown rsrc fork value */
#define SITFH_DATALONG      42 /* xadUINT32 unknown data fork value */
#define SITFH_DATACHAR      46 /* xadUINT8 unknown data (yes, data) fork value */
#define SITFH_RSRCCHAR      47 /* xadUINT8 unknown rsrc fork value */
#define SITFH_CHILDCOUNT    48 /* xadUINT16 number of items in dir */
#define SITFH_PREVOFFS      50 /* xadUINT32 offset of previous entry */
#define SITFH_NEXTOFFS      54 /* xadUINT32 offset of next entry */
#define SITFH_PARENTOFFS    58 /* xadUINT32 offset of parent entry */
#define SITFH_CHILDOFFS     62 /* xadINT32 offset of first child entry, -1 for file entries */

#define SITFH_FTYPE         66 /* xadUINT32 file type */
#define SITFH_CREATOR       70 /* xadUINT32 file creator */
#define SITFH_FNDRFLAGS     74 /* xadUINT16 Finder flags */
#define SITFH_CREATIONDATE  76 /* xadUINT32 creation date */
#define SITFH_MODDATE       80 /* xadUINT32 modification date */
#define SITFH_RSRCLENGTH    84 /* xadUINT32 decompressed rsrc length */
#define SITFH_DATALENGTH    88 /* xadUINT32 decompressed data length */
#define SITFH_COMPRLENGTH   92 /* xadUINT32 compressed rsrc length */
#define SITFH_COMPDLENGTH   96 /* xadUINT32 compressed data length */
#define SITFH_RSRCCRC      100 /* xadUINT16 crc of rsrc fork */
#define SITFH_DATACRC      102 /* xadUINT16 crc of data fork */

#define SITFH_RSRCPAD      104 /* xadUINT8 rsrc padding bytes for encryption */
#define SITFH_DATAPAD      105 /* xadUINT8 data padding bytes for encryption */
#define SITFH_DATAUNK1     106 /* xadUINT8 unknown data value, always 0? */
#define SITFH_DATAUNK2     107 /* xadUINT8 unknown data value, always 4 for encrypted? */
#define SITFH_RSRCUNK1     108 /* xadUINT8 unknown rsrc value, always 0? */
#define SITFH_RSRCUNK2     109 /* xadUINT8 unknown rsrc value, always 4 for encrypted? */

#define SITFH_HDRCRC       110 /* xadUINT16 crc of file header */
#define SIT_FILEHDRSIZE    112

#define StuffItEncryptedFlag 0x80 // password protected bit
#define StuffItStartFolder 0x20 // start of folder
#define StuffItEndFolder 0x21 // end of folder
#define StuffItFolderContainsEncrypted 0x10 // folder contains encrypted items bit
#define StuffItMethodMask (~StuffItEncryptedFlag)
#define StuffItFolderMask (~(StuffItEncryptedFlag|StuffItFolderContainsEncrypted))


-(void)parse
{
	[self setIsMacArchive:YES];

	CSHandle *fh=[self handle];
	off_t base=[fh offsetInFile];

	/*uint32_t signature=*/[fh readID];
	/*int numfiles=*/[fh readUInt16BE];
	int totalsize=[fh readUInt32BE];
	//uint32_t signature2=[fh readID];
	//int version=[fh readUInt8];
	//[fh skipBytes:1]; // reserved byte
	//uint32_t headersize=[fh readUInt32BE];
	//if (version==1) headersize=22;
	//int crc=[fh readUInt16BE];
	[fh skipBytes:12];

	XADResourceFork *fork=[self resourceFork];
	NSData *comment=[fork resourceDataForType:'SitC' identifier:0];
	if(comment) [self setObject:[self XADStringWithData:comment] forPropertyKey:XADCommentKey];

	XADPath *currdir=[self XADPath];

	while([fh offsetInFile]+SIT_FILEHDRSIZE<=totalsize+base && [self shouldKeepParsing])
	{
		uint8_t header[SIT_FILEHDRSIZE];
		[fh readBytes:112 toBuffer:header];

		if(CSUInt16BE(header+SITFH_HDRCRC)==XADCalculateCRC(0,header,110,XADCRCTable_a001))
		{
			int resourcelength=CSUInt32BE(header+SITFH_RSRCLENGTH);
			int resourcecomplen=CSUInt32BE(header+SITFH_COMPRLENGTH);
			int datalength=CSUInt32BE(header+SITFH_DATALENGTH);
			int datacomplen=CSUInt32BE(header+SITFH_COMPDLENGTH);
			int datamethod=header[SITFH_COMPDMETHOD];
			int resourcemethod=header[SITFH_COMPRMETHOD];
			int datapadding=header[SITFH_DATAPAD];
			int resourcepadding=header[SITFH_RSRCPAD];

			int namelen=header[SITFH_FNAMESIZE];
			if(namelen>31) namelen=31;

			XADString *name=[self XADStringWithBytes:header+SITFH_FNAME length:namelen];
			XADPath *path=[currdir pathByAppendingXADStringComponent:name];

			off_t start=[fh offsetInFile];

			if((datamethod&StuffItFolderMask)==StuffItStartFolder||
			(resourcemethod&StuffItFolderMask)==StuffItStartFolder)
			{
				NSMutableDictionary *dict=[NSMutableDictionary dictionaryWithObjectsAndKeys:
					path,XADFileNameKey,
					[NSDate XADDateWithTimeIntervalSince1904:CSUInt32BE(header+SITFH_MODDATE)],XADLastModificationDateKey,
					[NSDate XADDateWithTimeIntervalSince1904:CSUInt32BE(header+SITFH_CREATIONDATE)],XADCreationDateKey,
					[NSNumber numberWithInt:CSUInt16BE(header+SITFH_FNDRFLAGS)],XADFinderFlagsKey,
					[NSNumber numberWithBool:YES],XADIsDirectoryKey,
				nil];

				if((datamethod&StuffItFolderContainsEncrypted)!=0||
				(resourcemethod&StuffItFolderContainsEncrypted)!=0)
				{
					[dict setObject:[NSNumber numberWithBool:YES] forKey:XADIsEncryptedKey];
				}

				[self addEntryWithDictionary:dict];

				currdir=path;

				[fh seekToFileOffset:start];
			}
			else if((datamethod&StuffItFolderMask)==StuffItEndFolder||
			(resourcemethod&StuffItFolderMask)==StuffItEndFolder)
			{
				currdir=[currdir pathByDeletingLastPathComponent];
			}
			else
			{
				NSData *entrykey=nil;
				if(resourcelength)
				{
					NSMutableDictionary *dict=[NSMutableDictionary dictionaryWithObjectsAndKeys:
						path,XADFileNameKey,
						[NSNumber numberWithUnsignedInt:resourcelength],XADFileSizeKey,
						[NSNumber numberWithUnsignedInt:resourcecomplen],XADCompressedSizeKey,
						[NSDate XADDateWithTimeIntervalSince1904:CSUInt32BE(header+SITFH_MODDATE)],XADLastModificationDateKey,
						[NSDate XADDateWithTimeIntervalSince1904:CSUInt32BE(header+SITFH_CREATIONDATE)],XADCreationDateKey,
						[NSNumber numberWithUnsignedInt:CSUInt32BE(header+SITFH_FTYPE)],XADFileTypeKey,
						[NSNumber numberWithUnsignedInt:CSUInt32BE(header+SITFH_CREATOR)],XADFileCreatorKey,
						[NSNumber numberWithInt:CSUInt16BE(header+SITFH_FNDRFLAGS)],XADFinderFlagsKey,

						[NSNumber numberWithBool:YES],XADIsResourceForkKey,
						[NSNumber numberWithLongLong:start],XADDataOffsetKey,
						[NSNumber numberWithUnsignedInt:resourcecomplen],XADDataLengthKey,
						[NSNumber numberWithInt:resourcemethod&StuffItMethodMask],@"StuffItCompressionMethod",
						[NSNumber numberWithInt:CSUInt16BE(header+SITFH_RSRCCRC)],@"StuffItCRC16",
					nil];

					XADString *compressionname=[self nameOfCompressionMethod:resourcemethod];
					if(compressionname) [dict setObject:compressionname forKey:XADCompressionNameKey];

					if(resourcemethod&StuffItEncryptedFlag)
					{
						[dict setObject:[NSNumber numberWithBool:YES] forKey:XADIsEncryptedKey];
						if(resourcecomplen<16) [XADException raiseIllegalDataException];
						[dict setObject:[NSNumber numberWithUnsignedInt:resourcecomplen-16] forKey:XADDataLengthKey];
						// This sucks, as it causes resets in BinHex files.
						// There seems to be no way around it, though.
						[fh seekToFileOffset:start+resourcecomplen-16];
						entrykey=[fh readDataOfLength:16];
						[dict setObject:entrykey forKey:@"StuffItEntryKey"];
						[dict setObject:[NSNumber numberWithInt:resourcepadding] forKey:@"StuffItBlockPadding"];
					}

					// TODO: deal with this? if(!datalen&&datamethod==0) size=crunchsize

					[self addEntryWithDictionary:dict];
				}

				if(datalength||resourcelength==0)
				{
					NSMutableDictionary *dict=[NSMutableDictionary dictionaryWithObjectsAndKeys:
						path,XADFileNameKey,
						[NSNumber numberWithUnsignedInt:datalength],XADFileSizeKey,
						[NSNumber numberWithUnsignedInt:datacomplen],XADCompressedSizeKey,
						[NSDate XADDateWithTimeIntervalSince1904:CSUInt32BE(header+SITFH_MODDATE)],XADLastModificationDateKey,
						[NSDate XADDateWithTimeIntervalSince1904:CSUInt32BE(header+SITFH_CREATIONDATE)],XADCreationDateKey,
						[NSNumber numberWithUnsignedInt:CSUInt32BE(header+SITFH_FTYPE)],XADFileTypeKey,
						[NSNumber numberWithUnsignedInt:CSUInt32BE(header+SITFH_CREATOR)],XADFileCreatorKey,
						[NSNumber numberWithInt:CSUInt16BE(header+SITFH_FNDRFLAGS)],XADFinderFlagsKey,

						[NSNumber numberWithLongLong:start+resourcecomplen],XADDataOffsetKey,
						[NSNumber numberWithUnsignedInt:datacomplen],XADDataLengthKey,
						[NSNumber numberWithInt:datamethod&StuffItMethodMask],@"StuffItCompressionMethod",
						[NSNumber numberWithInt:CSUInt16BE(header+SITFH_DATACRC)],@"StuffItCRC16",
					nil];

					// TODO: figure out best way to link forks

					// TODO: deal with this? if(!datalen&&datamethod==0) size=crunchsize

					XADString *compressionname=[self nameOfCompressionMethod:datamethod];
					if(compressionname) [dict setObject:compressionname forKey:XADCompressionNameKey];

					if(datamethod&StuffItEncryptedFlag)
					{
						[dict setObject:[NSNumber numberWithBool:YES] forKey:XADIsEncryptedKey];
						if(datacomplen<16) [XADException raiseIllegalDataException];
						[dict setObject:[NSNumber numberWithUnsignedInt:datacomplen-16] forKey:XADDataLengthKey];
						// This sucks, as it causes resets in BinHex files.
						// There seems to be no way around it, though.
						[fh seekToFileOffset:start+resourcecomplen+datacomplen-16];
						entrykey=[fh readDataOfLength:16];
						[dict setObject:entrykey forKey:@"StuffItEntryKey"];
						[dict setObject:[NSNumber numberWithInt:datapadding] forKey:@"StuffItBlockPadding"];
					}

					[self addEntryWithDictionary:dict];
				}
				[fh seekToFileOffset:start+datacomplen+resourcecomplen];
			}
		}
		else [XADException raiseChecksumException];
	}
}

-(XADString *)nameOfCompressionMethod:(int)method
{
	NSString *compressionname=nil;
	switch(method&0x0f)
	{
		case 0: compressionname=@"None"; break;
		case 1: compressionname=@"RLE"; break;
		case 2: compressionname=@"Compress"; break;
		case 3: compressionname=@"Huffman"; break;
		case 5: compressionname=@"LZAH"; break;
		case 6: compressionname=@"Fixed Huffman"; break;
		case 8: compressionname=@"MW"; break;
		case 13: compressionname=@"LZ+Huffman"; break;
		case 14: compressionname=@"Installer"; break;
		case 15: compressionname=@"Arsenic"; break;
	}
	if(compressionname) return [self XADStringWithString:compressionname];
	else return nil;
}

-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum
{
	NSNumber *isdir=[dict objectForKey:XADIsDirectoryKey];
	if(isdir && [isdir boolValue]) return [self zeroLengthHandleWithChecksum:checksum];

	CSHandle *handle=[self handleAtDataOffsetForDictionary:dict];

	int compressionmethod=[[dict objectForKey:@"StuffItCompressionMethod"] intValue];
	off_t size=[[dict objectForKey:XADFileSizeKey] longLongValue];

	NSNumber *enc=[dict objectForKey:XADIsEncryptedKey];
	if(enc && [enc boolValue])
	{
		handle=[self decryptHandleForEntryWithDictionary:dict handle:handle];
	}
	
	switch(compressionmethod&0x0f)
	{
		case 0: break;
		case 1: handle=[[[XADRLE90Handle alloc] initWithHandle:handle length:size] autorelease]; break;
		case 2: handle=[[[XADCompressHandle alloc] initWithHandle:handle length:size flags:0x8e] autorelease]; break;
		case 3: handle=[[[XADStuffItHuffmanHandle alloc] initWithHandle:handle length:size] autorelease]; break;
		//case 5: handle=[[[XADStuffItLZAHHandle alloc] initWithHandle:handle inputLength:compsize outputLength:size] autorelease]; break;
		case 5: handle=[[[XADLZHDynamicHandle alloc] initWithHandle:handle length:size] autorelease]; break;
		// TODO: Figure out if the initialization of the window differs between LHArc and StuffIt
		//case 6:  fixed huffman
		case 8:
		{
			[self reportInterestingFileWithReason:@"Compression method 8 (MW)"];
			handle=[[[XADStuffItMWHandle alloc] initWithHandle:handle length:size] autorelease]; break;
		}
		case 13: handle=[[[XADStuffIt13Handle alloc] initWithHandle:handle length:size] autorelease]; break;
		case 14:
		{
			[self reportInterestingFileWithReason:@"Compression method 14"];
			handle=[[[XADStuffIt14Handle alloc] initWithHandle:handle length:size] autorelease]; break;
		}
		case 15: handle=[[[XADStuffItArsenicHandle alloc] initWithHandle:handle length:size] autorelease]; break;

		default:
			[self reportInterestingFileWithReason:@"Unsupported compression method %d",compressionmethod&0x0f];
			return nil;
	}

	if(checksum)
	{
		// TODO: handle arsenic
		if((compressionmethod&0x0f)==15) return handle;
		else return [XADCRCHandle IBMCRC16HandleWithHandle:handle length:size
		correctCRC:[[dict objectForKey:@"StuffItCRC16"] intValue] conditioned:NO];
	}

	return handle;
}

-(CSHandle *)decryptHandleForEntryWithDictionary:(NSDictionary *)dict handle:(CSHandle *)fh
{
	NSData *passworddata=[self encodedPassword];

	NSData *entrykey=[dict objectForKey:@"StuffItEntryKey"];
	if(!entrykey) [XADException raiseIllegalDataException];

	XADResourceFork *fork=[self resourceFork];
	NSData *mkey=[fork resourceDataForType:'MKey' identifier:0];
	if(!mkey) [XADException raiseNotSupportedException];

	NSData *key=[XADStuffItDESHandle keyForPasswordData:passworddata entryKey:entrykey MKey:mkey];
	if(!key) [XADException raisePasswordException];

	NSNumber *padding=[dict objectForKey:@"StuffItBlockPadding"];
	off_t inlength=[[dict objectForKey:XADDataLengthKey] longLongValue];
	if(inlength%8) [XADException raiseIllegalDataException];

	off_t outlength=inlength-[padding longLongValue];

	return [[[XADStuffItDESHandle alloc] initWithHandle:fh length:outlength key:key] autorelease];
}

-(NSString *)formatName { return @"StuffIt"; }

@end
