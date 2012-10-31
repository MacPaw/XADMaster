#import "XADStuffItParser.h"
#import "XADException.h"
#import "XADCRCHandle.h"
#import "NSDateXAD.h"

#import "XADStuffItHuffmanHandle.h"
#import "XADStuffItArsenicHandle.h"
#import "XADStuffIt13Handle.h"
#import "XADStuffItOldHandles.h"
#import "XADRLE90Handle.h"
#import "XADCompressHandle.h"
#import "XADLZHDynamicHandle.h"

#include <openssl/des.h>

static void StuffItDESSetKey(const_DES_cblock key,DES_key_schedule *ks);
static void StuffItDESCrypt(DES_cblock data,DES_key_schedule *ks,int enc);

@interface XADStuffItCipherHandle:CSBlockStreamHandle
{
	DES_cblock block;
	DES_LONG A, B, C, D;
}

+(int)keySize;
+(int)blockSize;

-(id)initWithHandle:(CSHandle *)handle key:(NSData *)keydata;
-(id)initWithHandle:(CSHandle *)handle length:(off_t)length key:(NSData *)keydata;

-(int)produceBlockAtOffset:(off_t)pos;

@end

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
						if(resourcecomplen<[XADStuffItCipherHandle keySize]) [XADException raiseIllegalDataException];
						[dict setObject:[NSNumber numberWithUnsignedInt:resourcecomplen-[XADStuffItCipherHandle keySize]] forKey:XADDataLengthKey];
						// This sucks, as it causes resets in BinHex files.
						// There seems to be no way around it, though.
						[fh seekToFileOffset:start+resourcecomplen-[XADStuffItCipherHandle keySize]];
						entrykey=[fh readDataOfLength:[XADStuffItCipherHandle keySize]];
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
						if(datacomplen<[XADStuffItCipherHandle keySize]) [XADException raiseIllegalDataException];
						[dict setObject:[NSNumber numberWithUnsignedInt:datacomplen-[XADStuffItCipherHandle keySize]] forKey:XADDataLengthKey];
						// This sucks, as it causes resets in BinHex files.
						// There seems to be no way around it, though.
						[fh seekToFileOffset:start+resourcecomplen+datacomplen-[XADStuffItCipherHandle keySize]];
						entrykey=[fh readDataOfLength:[XADStuffItCipherHandle keySize]];
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
	CSHandle *fh=[self handleAtDataOffsetForDictionary:dict];

	int compressionmethod=[[dict objectForKey:@"StuffItCompressionMethod"] intValue];
	off_t size=[[dict objectForKey:XADFileSizeKey] longLongValue];

	NSNumber *enc=[dict objectForKey:XADIsEncryptedKey];
	if(enc&&[enc boolValue])
	{
		fh=[self decryptHandleForEntryWithDictionary:dict handle:fh];
	}
	
	CSHandle *handle;
	switch(compressionmethod&0x0f)
	{
		case 0: handle=fh; break;
		case 1: handle=[[[XADRLE90Handle alloc] initWithHandle:fh length:size] autorelease]; break;
		case 2: handle=[[[XADCompressHandle alloc] initWithHandle:fh length:size flags:0x8e] autorelease]; break;
		case 3: handle=[[[XADStuffItHuffmanHandle alloc] initWithHandle:fh length:size] autorelease]; break;
		//case 5: handle=[[[XADStuffItLZAHHandle alloc] initWithHandle:fh inputLength:compsize outputLength:size] autorelease]; break;
		case 5: handle=[[[XADLZHDynamicHandle alloc] initWithHandle:fh length:size] autorelease]; break;
		// TODO: Figure out if the initialization of the window differs between LHArc and StuffIt
		//case 6:  fixed huffman
		case 8:
		{
			[self reportInterestingFileWithReason:@"Compression method 8 (MW)"];
			handle=[[[XADStuffItMWHandle alloc] initWithHandle:fh length:size] autorelease]; break;
		}
		case 13: handle=[[[XADStuffIt13Handle alloc] initWithHandle:fh length:size] autorelease]; break;
		case 14:
		{
			[self reportInterestingFileWithReason:@"Compression method 14"];
			handle=[[[XADStuffIt14Handle alloc] initWithHandle:fh length:size] autorelease]; break;
		}
		case 15: handle=[[[XADStuffItArsenicHandle alloc] initWithHandle:fh length:size] autorelease]; break;

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

-(NSData *)keyForEntryWithDictionary:(NSDictionary *)dict
{
	DES_key_schedule ks;

/*	// Encrypted archives require the MKey resource
	if(![fh hasForkOfType:CSResourceForkType])
		[XADException raiseNotSupportedException];
	CSHandle *rh=[fh forkHandleOfType:CSResourceForkType];
	XADResourceFork *fork=[[XADResourceFork alloc] initWithHandle:rh];
	NSData *mkey=[fork resourceDataForType:'MKey' withId:0];
	if(!mkey) [XADException raiseNotSupportedException];
*/

	NSData *mkey=nil;
	if(!mkey||[mkey length]!=sizeof(DES_cblock)) [XADException raiseIllegalDataException];

	NSData *entrykey=[dict objectForKey:@"StuffItEntryKey"];
	if(!entrykey) [XADException raiseIllegalDataException];

	DES_cblock passblock={0,0,0,0,0,0,0,0};
	int length=[[self encodedPassword] length];
	if(length>sizeof(DES_cblock)) length=sizeof(DES_cblock);
	memcpy(passblock, [[self encodedPassword] bytes], length);

	// Calculate archive key and IV from password and mkey
	DES_cblock archiveKey;
	DES_cblock archiveIV;

	const_DES_cblock initialKey={0x01,0x23,0x45,0x67,0x89,0xAB,0xCD,0xEF};
	StuffItDESSetKey(initialKey, &ks);
	for(int i=0; i<sizeof(DES_cblock); i++)
		archiveKey[i]=initialKey[i]^(passblock[i]&0x7F);
	StuffItDESCrypt(archiveKey, &ks, TRUE);
	
	StuffItDESSetKey(archiveKey, &ks);
	memcpy(archiveIV, [mkey bytes], sizeof(DES_cblock));
	StuffItDESCrypt(archiveIV, &ks, FALSE);

	// Verify the password
	DES_cblock verifyBlock={0,0,0,0,0,0,0,4};
	StuffItDESSetKey(archiveKey, &ks);
	memcpy(verifyBlock, archiveIV, 4);
	StuffItDESCrypt(verifyBlock, &ks, TRUE);
	if(memcmp(verifyBlock+4, archiveIV+4, 4)) return nil;

	// Calculate file key and IV from entrykey, archive key and IV
	DES_cblock fileKey;
	DES_cblock fileIV;
	memcpy(fileKey, [entrykey bytes], sizeof(DES_cblock));
	memcpy(fileIV, [entrykey bytes]+sizeof(DES_cblock), sizeof(DES_cblock));

	StuffItDESSetKey(archiveKey, &ks);
	StuffItDESCrypt(fileKey, &ks, FALSE);
	for (int i=0; i<sizeof(DES_cblock); i++)
		fileKey[i]^=archiveIV[i];
	StuffItDESSetKey(fileKey, &ks);
	StuffItDESCrypt(fileIV, &ks, FALSE);
	
	NSMutableData *key=[NSMutableData dataWithBytes:fileKey length:sizeof(DES_cblock)];
	NSData *iv=[NSData dataWithBytes:fileIV length:sizeof(DES_cblock)];
	[key appendData:iv];
	return key;
}

-(CSHandle *)decryptHandleForEntryWithDictionary:(NSDictionary *)dict handle:(CSHandle *)fh
{
	NSData *key=[self keyForEntryWithDictionary:dict];
	if(key)
	{
		NSNumber *padding=[dict objectForKey:@"StuffItBlockPadding"];
		off_t inlength=[[dict objectForKey:XADDataLengthKey] longLongValue];
		if(inlength%[XADStuffItCipherHandle blockSize]) [XADException raiseIllegalDataException];
		off_t outlength=inlength-[padding longLongValue];
		return [[[XADStuffItCipherHandle alloc] initWithHandle:fh length:outlength key:key] autorelease];
	}
	else
	{
		[XADException raisePasswordException];
		return nil;
	}
}

-(NSString *)formatName { return @"StuffIt"; }

@end


#define ROTATE(a,n) (((a)>>(n))+((a)<<(32-(n))))
#define READ_32BE(p) ((((p)[0]&0xFF)<<24)|(((p)[1]&0xFF)<<16)|(((p)[2]&0xFF)<<8)|((p)[3]&0xFF))
#define READ_64BE(p, l, r) { l=READ_32BE(p); r=READ_32BE((p)+4); }
#define WRITE_32BE(p, n) (p)[0]=(n)>>24,(p)[1]=(n)>>16,(p)[2]=(n)>>8,(p)[3]=(n)
#define WRITE_64BE(p, l, r) { WRITE_32BE(p, l); WRITE_32BE((p)+4, r); }

@implementation XADStuffItCipherHandle

+(int)keySize
{
	return sizeof(DES_cblock)*2;
}

+(int)blockSize
{
	return sizeof(DES_cblock);
}

-(id)initWithHandle:(CSHandle *)handle key:(NSData *)keydata
{
	return [self initWithHandle:handle length:CSHandleMaxLength key:keydata];
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length key:(NSData *)keydata
{
	if([keydata length]!=[XADStuffItCipherHandle keySize]) [XADException raiseUnknownException];
	if((self=[super initWithHandle:handle length:length]))
	{
		const uint8_t *keybytes=[keydata bytes];
		READ_64BE(keybytes, A, B);
		READ_64BE(keybytes+sizeof(DES_cblock), C, D);
		[self setBlockPointer:block];
	}
	return self;
}

-(int)produceBlockAtOffset:(off_t)pos
{
	for(int i=0;i<sizeof(block);i++)
	{
		if(CSInputAtEOF(input)) [XADException raiseIllegalDataException];
		block[i]=CSInputNextByte(input);
	}
	
	DES_LONG left, right, l, r;
	READ_64BE(block, left, right);
	l=left ^A^C;
	r=right^B^D;
	WRITE_64BE(block, l, r);

	//DES_LONG oldC=C;
	C=D;
	//if (enc) D=ROTATE(left^right^oldC, 1); else
	D=ROTATE(left^right^A^B^D, 1);

	return sizeof(block);
}

@end


/*
 StuffItDES is a modified DES that ROLs the input, does the DES rounds
 without IP, then RORs result.  It also uses its own key schedule.
 It is only used for key management.
 */

DES_LONG _reverseBits(DES_LONG in)
{
	DES_LONG out=0;
	int i;
	for(i=0; i<32; i++)
	{
		out<<=1;
		out|=in&1;
		in>>=1;
	}
	return out;
}

static void StuffItDESSetKey(const_DES_cblock key, DES_key_schedule* ks)
{
	int i;
	DES_LONG subkey0, subkey1;
	
#define NIBBLE(i) ((key[((i)&0x0F)>>1]>>((((i)^1)&1)<<2))&0x0F)
	for(i=0; i<16; i++)
	{
		subkey1 =((NIBBLE(i)>>2)|(NIBBLE(i+13)<<2));
		subkey1|=((NIBBLE(i+11)>>2)|(NIBBLE(i+6)<<2))<<8;
		subkey1|=((NIBBLE(i+3)>>2)|(NIBBLE(i+10)<<2))<<16;
		subkey1|=((NIBBLE(i+8)>>2)|(NIBBLE(i+1)<<2))<<24;		
		subkey0 =((NIBBLE(i+9)|(NIBBLE(i)<<4))&0x3F);
		subkey0|=((NIBBLE(i+2)|(NIBBLE(i+11)<<4))&0x3F)<<8;
		subkey0|=((NIBBLE(i+14)|(NIBBLE(i+3)<<4))&0x3F)<<16;
		subkey0|=((NIBBLE(i+5)|(NIBBLE(i+8)<<4))&0x3F)<<24;
		ks->ks[i].deslong[1]=subkey1;
		ks->ks[i].deslong[0]=subkey0;
	}
#undef NIBBLE
	
	/* OpenSSL's DES implementation treats its input as little-endian
	 (most don't), so in order to build the internal key schedule
	 the way OpenSSL expects, we need to bit-reverse the key schedule
	 and swap the even/odd subkeys.  Also, because of an internal rotation
	 optimization, we need to rotate the second subkeys left 4.  None
	 of this is necessary for a standard DES implementation.
	 */
	for(i=0; i<16; i++)
	{
		/* Swap subkey pair */
		subkey0=ks->ks[i].deslong[1];
		subkey1=ks->ks[i].deslong[0];
		/* Reverse bits */
		subkey0=_reverseBits(subkey0);
		subkey1=_reverseBits(subkey1);
		/* Rotate second subkey left 4 */
		subkey1=ROTATE(subkey1,28);
		/* Write back OpenSSL-tweaked subkeys */
		ks->ks[i].deslong[0]=subkey0;
		ks->ks[i].deslong[1]=subkey1;
	}
}

#define PERMUTATION(a,b,t,n,m) \
(t)=((((a)>>(n))^(b))&(m)); \
(b)^=(t); \
(a)^=((t)<<(n))

void _initialPermutation(DES_LONG *ioLeft, DES_LONG *ioRight)
{
	DES_LONG temp;
	DES_LONG left=*ioLeft;
	DES_LONG right=*ioRight;
	PERMUTATION(left, right, temp, 4, 0x0f0f0f0fL);
	PERMUTATION(left, right, temp,16, 0x0000ffffL);
	PERMUTATION(right, left, temp, 2, 0x33333333L);
	PERMUTATION(right, left, temp, 8, 0x00ff00ffL);
	PERMUTATION(left, right, temp, 1, 0x55555555L);
	left=ROTATE(left, 31);
	right=ROTATE(right, 31);
	*ioLeft=left;
	*ioRight=right;
}

void _finalPermutation(DES_LONG *ioLeft, DES_LONG *ioRight)
{
	DES_LONG temp;
	DES_LONG left=*ioLeft;
	DES_LONG right=*ioRight;
	left=ROTATE(left, 1);
	right=ROTATE(right, 1);
	PERMUTATION(left, right, temp, 1, 0x55555555L);
	PERMUTATION(right, left, temp, 8, 0x00ff00ffL);
	PERMUTATION(right, left, temp, 2, 0x33333333L);
	PERMUTATION(left, right, temp,16, 0x0000ffffL);
	PERMUTATION(left, right, temp, 4, 0x0f0f0f0fL);
	*ioLeft=left;
	*ioRight=right;
}


static void StuffItDESCrypt(DES_cblock data, DES_key_schedule* ks, int enc)
{
	DES_LONG left, right;
	DES_cblock input, output;
	
	READ_64BE(data, left, right);
	
	/* This DES variant ROLs the input and RORs the output */
	left=ROTATE(left, 31);
	right=ROTATE(right, 31);
	
	/* This DES variant skips the initial permutation (and subsequent inverse).
	 Since we want to use a standard DES library (which includes them), we
	 wrap the encryption with the inverse permutations.
	 */
	_finalPermutation(&left, &right);
	
	WRITE_64BE(input, left, right);
	
	DES_ecb_encrypt(&input, &output, ks, enc);
	
	READ_64BE(output, left, right);
	
	_initialPermutation(&left, &right);
	
	left=ROTATE(left, 1);
	right=ROTATE(right, 1);
	
	WRITE_64BE(data, left, right);
}

