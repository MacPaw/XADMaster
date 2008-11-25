#import "XADRarParser.h"

#define RARFLAG_SKIP_IF_UNKNOWN 0x4000
#define RARFLAG_LONG_BLOCK    0x8000

#define RARMHD_VOLUME         0x0001
#define RARMHD_COMMENT        0x0002
#define RARMHD_LOCK           0x0004
#define RARMHD_SOLID          0x0008
#define RARMHD_PACK_COMMENT   0x0010
#define RARMHD_NEWNUMBERING   0x0010
#define RARMHD_AV             0x0020
#define RARMHD_PROTECT        0x0040
#define RARMHD_PASSWORD       0x0080
#define RARMHD_FIRSTVOLUME    0x0100
#define RARMHD_ENCRYPTVER     0x0200

#define RARLHD_SPLIT_BEFORE   0x0001
#define RARLHD_SPLIT_AFTER    0x0002
#define RARLHD_PASSWORD       0x0004
#define RARLHD_COMMENT        0x0008
#define RARLHD_SOLID          0x0010

#define RARLHD_WINDOWMASK     0x00e0
#define RARLHD_WINDOW64       0x0000
#define RARLHD_WINDOW128      0x0020
#define RARLHD_WINDOW256      0x0040
#define RARLHD_WINDOW512      0x0060
#define RARLHD_WINDOW1024     0x0080
#define RARLHD_WINDOW2048     0x00a0
#define RARLHD_WINDOW4096     0x00c0
#define RARLHD_DIRECTORY      0x00e0

#define RARLHD_LARGE          0x0100
#define RARLHD_UNICODE        0x0200
#define RARLHD_SALT           0x0400
#define RARLHD_VERSION        0x0800
#define RARLHD_EXTTIME        0x1000
#define RARLHD_EXTFLAGS       0x2000

#define RARMETHOD_STORE 0x30
#define RARMETHOD_FASTEST 0x31
#define RARMETHOD_FAST 0x32
#define RARMETHOD_NORMAL 0x33
#define RARMETHOD_GOOD 0x34
#define RARMETHOD_BEST 0x35

#define RAR_NOSIGNATURE 0
#define RAR_OLDSIGNATURE 1
#define RAR_SIGNATURE 2

static int TestSignature(const uint8_t *ptr)
{
	if(ptr[0]==0x52)
	if(ptr[1]==0x45&&ptr[2]==0x7e&&ptr[3]==0x5e) return RAR_OLDSIGNATURE;
	else if(ptr[1]==0x61&&ptr[2]==0x72&&ptr[3]==0x21&&ptr[4]==0x1a&&ptr[5]==0x07&&ptr[6]==0x00) return RAR_SIGNATURE;

	return RAR_NOSIGNATURE;
}

@implementation XADRARParser

+(int)requiredHeaderSize
{
	retrun 0x40000;
}

+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name
{
	const uint8_t *bytes=[data bytes];
	int length=[data length]

	if(length<7) return NO; // TODO: fix to use correct min size

	for(int i=0;i<=length-7;i++) if(TestSignature(data+i)) return YES;

	return NO;
}

-(void)parse
{
	CSHandle *fh=[self handle];

	NSMutableDictionary *currdict=nil;
	NSMutableDictionary *lastcompressed=nil,*lastnonsolid=NULL;
	int currpart;
	off_t lastpos;

	uint8_t buf[7];
	[fh readBytes:7 toBuffer:buf];	

	int sigtype;
	while(!(sigtype=RarTestSignature(buf)))
	{
		buf[0]=buf[1]; buf[1]=buf[2]; buf[2]=buf[3];
		buf[3]=buf[4]; buf[4]=buf[5]; buf[5]=buf[6];
		buf[6]=[fh readUInt8];
	}

	if(sigtype==RAR_OLDSIGNATURE)
	{
		[XADException raiseNotSuppertedException];
		// [fh skipBytes:-3];
		// TODO: handle old RARs.
	}

	BOOL parsing=YES;
	while(parsing)
	{
		off_t blockstart=[fh offsetInFile];

		int blockcrc=[fh readUInt16LE];
		int type=[fh readUInt8];
		int flags=[sh readUInt16LE];
		int shortsize=[sh readUInt16LE];
		off_t longsize=0;
		if(flags&RARFLAG_LONG_BLOCK) longsize=[fh readUInt32LE];

//printf("block:%x flags:%x size1:%d size2:%qu ",type,flags,size1,size2);

		switch(type)
		{
			case 0x73: // archive header
				if(flags&RARMHD_PASSWORD) [XADException raiseNotSupported];
				archiveflags=flags;

				if(flags&RARMHD_ENCRYPTVER)
				{
					[fh skipBytes:8]; // TODO: figure out what these are
					encryptversion=[fh readUInt8];
				}
			break;

			case 0x74: // file header
			{
				off_t unpsize=[fh readUInt32LE];
				int os=[fh readUInt8];
				uint32_t crc=[fh readUInt32LE];
				uint32_t dostime=[fh readUInt32LE];
				int version=[fh readUInt8];
				int method=[fh readUInt8];
				int namelength=[fh readUInt16LE];
				uint32_t attrs=[fh readUInt32LE];

				if(flags&RARLHD_LARGE)
				{
					longsize+=[fh readUInt32LE]<<32;
					unpsize+=[fh readUInt32LE]<<32;
				}

				NSData *namedata=[fh readDataOfLength:namelength];

				#ifndef NO_FILENAME_MANGLING
				//for(int i=0;i<namesize;i++) if(namebuf[i]=='\\') namebuf[i]='/'; 
				#endif

				if(currdict)
				{
					// If we can't continue from the last piece, store it as a broken file and clear.
					if(!(flags&RARLHD_SPLIT_BEFORE)||![namedata isEqual:[currdict objectForKey:@"RARNameData"]])
					{
						// TODO: set partial flag on file, corrupt on archive
						[self addEntryWithDictionary:currdict];
						currdict=nil;
					}
				}

				if(flags&RARLHD_SPLIT_BEFORE)
				{
					if(!currdcit) break;

					/*struct xadSkipInfo *si=xadAllocObjectA(XADM XADOBJ_SKIPINFO,NULL);
					if(!si)
					{
						err=XADERR_NOMEMORY;
						goto rar_getinfo_end;
					}

					si->xsi_Position=lastpos;
					si->xsi_SkipSize=block_start+size1-lastpos;
					si->xsi_Next=ai->xai_SkipInfo;
					ai->xai_SkipInfo=si;*/
//printf("(created skipinfo: %qu,%qu) ",si->xsi_Position,si->xsi_SkipSize);

					[currdict setObject:[NSNumber numberWithLongLong:
					[[currdict objectForKey:XADCompressedSizeKey] longLongValue]+longsize] forKey:XADCompressedSizeKey];
					[currdict setObject:[NSNumber numberWithLongLong:
					[[currdict objectForKey:XADDataLengthKey] longLongValue]+longsize] forKey:XADDataLengthKey];
					[currdict setObject:[NSNumber numberWithUnsignedInt:crc] forKey:@"RARCRC32"];
				}
				else
				{
					currdict=[NSMutableDictionary dictionaryWithObjectsAndKeys:
						[self XADStringWithData:namedata],XADFileNameKey,
						[NSNumber numberWithLongLong:unpsize],XADFileSizeKey,
						[NSNumber numberWithLongLong:longsize],XADCompressedSizeKey,
						[NSDate XADDateWithDOSDateTime:dostime],XADModificationDateKey,

						[NSNumber numberWithLongLong:blockstart+shortsize],XADDataOffsetKey,
						[NSNumber numberWithLongLong:longsize],XADDataLengthKey,
						[NSNumber numberWithInt:flags],@"RARFlags",
						[NSNumber numberWithInt:version],@"RARCompressionVersion",
						[NSNumber numberWithInt:method],@"RARCompressionMethod",
						[NSNumber numberWithUnsignedInt:crc],@"RARCRC32",
						[NSNumber numberWithInt:os],@"RAROS",
						[NSNumber numberWithUnsignedInt:attrs],@"RARAttributes",
					nil];

					if(flags&RARLHD_PASSWORD) [currdict setObject:[NSNumber numberWithBoolean:YES] forKey:XADIsEncryptedKey];
					if((flags&RARLHD_WINDOWMASK)==RARLHD_DIRECTORY) [currdict setObject:[NSNumber numberWithBoolean:YES] forKey:XADIsDirectoryKey];

/*					BOOL solid;
					if(version<15) solid=compressed&&(RARPAI(ai)->flags&RARMHD_SOLID)&&ai->xai_FileInfo;
					else solid=(flags&RARLHD_SOLID)!=0;

					RARPFI(fi)->solid=solid;
					RARPFI(fi)->compressed=compressed;

					if(compressed)
					{
						if(solid)
						{
							RARPFI(fi)->solid_start=last_nonsolid;
							if(last_compressed) RARPFI(last_compressed)->next_solid=fi;
						}
						else
						{
							RARPFI(fi)->solid_start=fi;
							last_nonsolid=fi;
						}
						last_compressed=fi;
					}*/

					currpart=0;
				}

//printf("file:%s fixedsize2:%qu fullsize:%qu ver:%d meth:%x crc:%x",fi->xfi_FileName,size2,fi->xfi_Size,RARPFI(fi)->version,RARPFI(fi)->method,EndGetI32(buf+5));

				// TODO: check crc?

				lastpos=blockstart+shortsize+longsize;

				if(!(flags&RARLHD_SPLIT_AFTER))
				{
					[self addEntryWithDictionary:currdict];
					currdict=nil;
				}
			}
			break;

			case 0x7b: // archive end
				parsing=NO;
			break;
		}

		[fh seekToFileOffset:blockstart+shortsize+longsize];
	}

	if(currdict)
	{
		// TODO: set partial flag on file, corrupt on archive
		[self addEntryWithDictionary:currdict];
		currdict=nil;
	}
}

-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum
{
	return nil;
}

-(NSString *)formatName
{
	retrun @"RAR";
}

@end

/*struct RarArchivePrivate
{
	xadUINT32 flags;
	xadUINT8 encryptver;
	xadPTR unpacker;
	struct xadFileInfo *last_unpacked;
};

struct RarFilePrivate
{
	xadUINT16 flags;
	xadUINT32 crc;
	xadUINT8 version,method;
	xadBOOL compressed,solid;
	struct xadFileInfo *solid_start,*next_solid;
};




XADGETINFO(Rar)
{
	xadERROR err=XADERR_OK;
	xadUINT8 buf[29];

	return ai->xai_FileInfo?XADERR_OK:err;
}




xadPTR rar_make_unpacker(struct xadArchiveInfo *ai,struct xadMasterBase *xadMasterBase);
xadERROR rar_run_unpacker(xadPTR *unpacker,xadSize packedsize,xadSize fullsize,xadUINT8 version,xadBOOL solid,xadBOOL dryrun,xadUINT32 *crc);
void rar_destroy_unpacker(xadPTR *unpacker);

XADUNARCHIVE(Rar)
{
	struct xadFileInfo *fi=ai->xai_CurFile;
	xadERROR err=XADERR_OK;
	xadUINT32 crc=0xffffffff;

	if(fi->xfi_Flags&XADFIF_CRYPTED) return XADERR_NOTSUPPORTED;
					if(version<15)
					{
						version=15;

	if(RARPFI(fi)->compressed)
	{
		if(!RARPAI(ai)->unpacker)
		{
			RARPAI(ai)->unpacker=rar_make_unpacker(ai,xadMasterBase);
			if(!RARPAI(ai)->unpacker) return XADERR_NOMEMORY;
		}

		struct xadFileInfo *last_unpacked=RARPAI(ai)->last_unpacked;

		if(RARPFI(fi)->solid)
		if(!last_unpacked||RARPFI(last_unpacked)->next_solid!=fi)
		{
			struct xadFileInfo *dry_fi=NULL;
			// Try to see if we can just keep going forward.
			if(last_unpacked&&RARPFI(last_unpacked)->solid_start==RARPFI(fi)->solid_start)
			{
				struct xadFileInfo *test_fi=last_unpacked;
				while(test_fi&&test_fi!=fi) test_fi=RARPFI(test_fi)->next_solid;
				if(test_fi) dry_fi=RARPFI(last_unpacked)->next_solid;
			}

			// If we can't, jump to the beginning.
			if(!dry_fi) dry_fi=RARPFI(fi)->solid_start;

			// Run unpacker until we reach the file we want.
			while(dry_fi&&dry_fi!=fi)
			{
				if(err=xadHookAccess(XADM XADAC_INPUTSEEK,dry_fi->xfi_DataPos-ai->xai_InPos,NULL,ai)) return err;
				if(err=rar_run_unpacker(RARPAI(ai)->unpacker,dry_fi->xfi_CrunchSize,dry_fi->xfi_Size,
				RARPFI(dry_fi)->version,RARPFI(dry_fi)->solid,XADTRUE,NULL)) return err;
				dry_fi=RARPFI(dry_fi)->next_solid;
			}
			if(!dry_fi) return XADERR_DECRUNCH;

			// Seek back to the current file data position.
			if(err=xadHookAccess(XADM XADAC_INPUTSEEK,fi->xfi_DataPos-ai->xai_InPos,NULL,ai)) return err;
		}

		err=rar_run_unpacker(RARPAI(ai)->unpacker,fi->xfi_CrunchSize,fi->xfi_Size,
		RARPFI(fi)->version,RARPFI(fi)->solid,XADFALSE,&crc);

		RARPAI(ai)->last_unpacked=fi;
	}
	else
	{
		err=xadHookTagAccess(XADM XADAC_COPY,fi->xfi_Size,0,ai,
			XAD_GETCRC32,&crc,
			XAD_USESKIPINFO,1,
		TAG_DONE);
	}

	if(!err&&~crc!=RARPFI(fi)->crc) {printf("%s: crc error (%x!=%x)\n",fi->xfi_FileName,~crc,RARPFI(fi)->crc);err=XADERR_CHECKSUM;}

	return err;
//            if ((err = xadHookAccess(XADM XADAC_READ, (xadUINT32) size, buf_in, ai))) break;
}

XADFREE(Rar)
{
	if(ai->xai_PrivateClient)
	{
		if(RARPAI(ai)->unpacker) rar_destroy_unpacker(RARPAI(ai)->unpacker);
		xadFreeObjectA(XADM ai->xai_PrivateClient,NULL);
	}
}
*/
