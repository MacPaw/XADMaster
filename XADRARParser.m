#import "XADRARParser.h"
#import "XADRARHandle.h"
#import "XADRARAESHandle.h"
#import "XADException.h"
#import "Checksums.h"
#import "NSDateXAD.h"

#define RARFLAG_SKIP_IF_UNKNOWN 0x4000
#define RARFLAG_LONG_BLOCK    0x8000

#define MHD_VOLUME         0x0001
#define MHD_COMMENT        0x0002
#define MHD_LOCK           0x0004
#define MHD_SOLID          0x0008
#define MHD_PACK_COMMENT   0x0010
#define MHD_NEWNUMBERING   0x0010
#define MHD_AV             0x0020
#define MHD_PROTECT        0x0040
#define MHD_PASSWORD       0x0080
#define MHD_FIRSTVOLUME    0x0100
#define MHD_ENCRYPTVER     0x0200

#define LHD_SPLIT_BEFORE   0x0001
#define LHD_SPLIT_AFTER    0x0002
#define LHD_PASSWORD       0x0004
#define LHD_COMMENT        0x0008
#define LHD_SOLID          0x0010

#define LHD_WINDOWMASK     0x00e0
#define LHD_WINDOW64       0x0000
#define LHD_WINDOW128      0x0020
#define LHD_WINDOW256      0x0040
#define LHD_WINDOW512      0x0060
#define LHD_WINDOW1024     0x0080
#define LHD_WINDOW2048     0x00a0
#define LHD_WINDOW4096     0x00c0
#define LHD_DIRECTORY      0x00e0

#define LHD_LARGE          0x0100
#define LHD_UNICODE        0x0200
#define LHD_SALT           0x0400
#define LHD_VERSION        0x0800
#define LHD_EXTTIME        0x1000
#define LHD_EXTFLAGS       0x2000

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
	return 0x40000;
}

+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name
{
	const uint8_t *bytes=[data bytes];
	int length=[data length];

	if(length<7) return NO; // TODO: fix to use correct min size

	for(int i=0;i<=length-7;i++) if(TestSignature(bytes+i)) return YES;

	return NO;
}

+(XADRegex *)volumeRegexForFilename:(NSString *)filename
{
	NSArray *matches;

	if(matches=[filename substringsCapturedByPattern:@"^(.*)\\.part[0-9]+\\.rar$" options:REG_ICASE])
	return [XADRegex regexWithPattern:[NSString stringWithFormat:
	@"^%@\\.part[0-9]+\\.rar$",[[matches objectAtIndex:1] escapedPattern]] options:REG_ICASE];

	if(matches=[filename substringsCapturedByPattern:@"^(.*)\\.(rar|r[0-9]{2}|s[0-9]{2})$" options:REG_ICASE])
	return [XADRegex regexWithPattern:[NSString stringWithFormat:
	@"^%@\\.(rar|r[0-9]{2}|s[0-9]{2})$",[[matches objectAtIndex:1] escapedPattern]] options:REG_ICASE];

	return nil;
}

+(BOOL)isFirstVolume:(NSString *)filename
{
	return [filename rangeOfString:@".rar" options:NSAnchoredSearch|NSCaseInsensitiveSearch|NSBackwardsSearch].location!=NSNotFound;
}

-(void)parse
{
	CSHandle *handle=[self handle];
	XADRARAESHandle *encryptedhandle=nil;

	NSMutableDictionary *currdict=nil;
	NSMutableDictionary *lastcompressed=nil,*lastnonsolid=NULL;
	int currpart;
	off_t lastpos;

	uint8_t buf[7];
	[handle readBytes:7 toBuffer:buf];	

	int sigtype;
	while(!(sigtype=TestSignature(buf)))
	{
		buf[0]=buf[1]; buf[1]=buf[2]; buf[2]=buf[3];
		buf[3]=buf[4]; buf[4]=buf[5]; buf[5]=buf[6];
		buf[6]=[handle readUInt8];
	}

	if(sigtype==RAR_OLDSIGNATURE)
	{
		[XADException raiseNotSupportedException];
		// [fh skipBytes:-3];
		// TODO: handle old RARs.
	}

	archiveflags=0;

	for(;;)
	{
		off_t blockstart=[handle offsetInFile];

		CSHandle *fh=encryptedhandle?encryptedhandle:handle;

		@try { /*int blockcrc=*/[fh readUInt16LE]; }
		@catch(id e) { break; }

		int type=[fh readUInt8];
		int flags=[fh readUInt16LE];
		int headersize=[fh readUInt16LE];
		off_t datasize=0;
		if(flags&RARFLAG_LONG_BLOCK) datasize=[fh readUInt32LE];

NSLog(@"block:%x flags:%x size1:%d size2:%qu ",type,flags,headersize,datasize);

		switch(type)
		{
			case 0x73: // archive header
				archiveflags=flags;

				if(flags&MHD_ENCRYPTVER)
				{
					[fh skipBytes:6]; // Skip signature stuff
					encryptversion=[fh readUInt8];
NSLog(@"encryptver: %d",encryptversion);
				}
				else encryptversion=0; // ?

				if(flags&MHD_PASSWORD)
				{
					// Salt is stored at the start of the next block for some reason
					[fh seekToFileOffset:blockstart+headersize+datasize];
					NSData *salt=[fh readDataOfLength:8];

					// TODO: check for password

					encryptedhandle=[[[XADRARAESHandle alloc] initWithHandle:fh
					password:[self password] salt:salt brokenHash:encryptversion<36] autorelease];

					// Kludge position so the next seek goes to the right place
					blockstart+=8;
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

				if(flags&LHD_LARGE)
				{
					datasize+=(off_t)[fh readUInt32LE]<<32;
					unpsize+=(off_t)[fh readUInt32LE]<<32;
				}

				NSData *namedata=[fh readDataOfLength:namelength];
				// TODO: unicode names

				if(currdict)
				{
					// If we can't continue from the last piece, store it as a broken file and clear.
					if(!(flags&LHD_SPLIT_BEFORE)||![namedata isEqual:[currdict objectForKey:@"RARNameData"]])
					{
						// TODO: set partial flag on file, corrupt on archive
						[self addEntryWithDictionary:currdict];
						currdict=nil;
					}
				}

				if(flags&LHD_SPLIT_BEFORE)
				{
					if(!currdict) break;

					[[self skipHandle] addSkipFrom:lastpos to:blockstart+headersize];

					[currdict setObject:[NSNumber numberWithLongLong:
					[[currdict objectForKey:XADCompressedSizeKey] longLongValue]+datasize] forKey:XADCompressedSizeKey];
					[currdict setObject:[NSNumber numberWithLongLong:
					[[currdict objectForKey:XADDataLengthKey] longLongValue]+datasize] forKey:XADDataLengthKey];
					[currdict setObject:[NSNumber numberWithUnsignedInt:crc] forKey:@"RARCRC32"];
				}
				else
				{
					currdict=[NSMutableDictionary dictionaryWithObjectsAndKeys:
						[self XADStringWithData:namedata],XADFileNameKey,
						[NSNumber numberWithLongLong:unpsize],XADFileSizeKey,
						[NSNumber numberWithLongLong:datasize],XADCompressedSizeKey,
						[NSDate XADDateWithMSDOSDateTime:dostime],XADLastModificationDateKey,

						[NSNumber numberWithLongLong:blockstart+headersize],XADDataOffsetKey,
						[NSNumber numberWithLongLong:datasize],XADDataLengthKey,
						[NSNumber numberWithInt:flags],@"RARFlags",
						[NSNumber numberWithInt:version],@"RARCompressionVersion",
						[NSNumber numberWithInt:method],@"RARCompressionMethod",
						[NSNumber numberWithUnsignedInt:crc],@"RARCRC32",
						[NSNumber numberWithInt:os],@"RAROS",
						[NSNumber numberWithUnsignedInt:attrs],@"RARAttributes",
						namedata,@"RARNameData",
					nil];

					if(flags&LHD_PASSWORD) [currdict setObject:[NSNumber numberWithBool:YES] forKey:XADIsEncryptedKey];
					if((flags&LHD_WINDOWMASK)==LHD_DIRECTORY) [currdict setObject:[NSNumber numberWithBool:YES] forKey:XADIsDirectoryKey];
					if(os==3) [currdict setObject:[NSNumber numberWithUnsignedInt:attrs] forKey:XADPosixPermissionsKey];

					NSString *methodname=nil;
					switch(method)
					{
						case 0x30: methodname=@"None"; break;
						case 0x31: methodname=[NSString stringWithFormat:@"Fastest v%d.%d",version/10,version%10]; break;
						case 0x32: methodname=[NSString stringWithFormat:@"Fast v%d.%d",version/10,version%10]; break;
						case 0x33: methodname=[NSString stringWithFormat:@"Normal v%d.%d",version/10,version%10]; break;
						case 0x34: methodname=[NSString stringWithFormat:@"Good v%d.%d",version/10,version%10]; break;
						case 0x35: methodname=[NSString stringWithFormat:@"Best v%d.%d",version/10,version%10]; break;
					}
					if(methodname) [currdict setObject:[self XADStringWithString:methodname] forKey:XADCompressionNameKey];

					if(method!=0x30) // handle solidness, only for compressed files
					{
						BOOL solid;
						if(version<15) solid=(archiveflags&MHD_SOLID)&&lastcompressed;
						else solid=(flags&LHD_SOLID)!=0;

						if(solid)
						{
							[currdict setObject:[NSNumber numberWithBool:YES] forKey:XADIsSolidKey];
							//RARPFI(fi)->solid_start=last_nonsolid;
							//if(last_compressed) RARPFI(last_compressed)->next_solid=fi;
						}
						else
						{
							lastnonsolid=currdict;
						}
						lastcompressed=currdict;
					}

					currpart=0;
				}

				// TODO: check crc?

				lastpos=blockstart+headersize+datasize;

				if(!(flags&LHD_SPLIT_AFTER))
				{
					[self addEntryWithDictionary:currdict];
					currdict=nil;
				}
			}
			break;
		}

		if(encryptedhandle) [encryptedhandle readAndDiscardBytes:blockstart+headersize-[handle offsetInFile]];
		[handle seekToFileOffset:blockstart+headersize+datasize];
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
	CSHandle *handle=[self handleAtDataOffsetForDictionary:dict];
	off_t size=[[dict objectForKey:XADFileSizeKey] longLongValue];

	if([[dict objectForKey:@"RARCompressionMethod"] intValue]!=0x30)
	handle=[[[XADRARHandle alloc] initWithHandle:handle length:size
	version:[[dict objectForKey:@"RARCompressionVersion"] intValue]] autorelease];

	if(checksum) handle=[XADCRCHandle IEEECRC32HandleWithHandle:handle length:size
	correctCRC:[[dict objectForKey:@"RARCRC32"] unsignedIntValue] conditioned:YES];

	return handle;
}

-(NSString *)formatName
{
	return @"RAR";
}

@end
