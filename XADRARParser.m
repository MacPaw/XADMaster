#import "XADRARParser.h"
#import "XADRARHandle.h"
#import "XADRARAESHandle.h"
#import "XADCRCHandle.h"
#import "CSMemoryHandle.h"
#import "XADException.h"
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

static RARBlock ZeroBlock={0};

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



-(id)initWithHandle:(CSHandle *)handle name:(NSString *)name
{
	if(self=[super initWithHandle:handle name:name])
	{
		currhandle=nil;
		currparts=nil;
	}
	return self;
}

-(void)dealloc
{
	[currhandle release];
	[currparts release];
	[super dealloc];
}


-(void)parse
{
	CSHandle *handle=[self handle];

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

	RARBlock block=[self readArchiveHeader];

	lastcompressed=lastnonsolid=nil;

	while(block.start!=0)
	{
		//NSAutoreleasePool *pool=[NSAutoreleasePool new];
		block=[self readFileHeaderWithBlock:block];
		//[pool release];
	}
}

-(RARBlock)readArchiveHeader
{
	CSHandle *fh=[self handle];
	RARBlock block;

	archiveflags=0;

	for(;;)
	{
		block=[self readBlockHeader];

		if(block.type==0x73) // archive header
		{
			archiveflags=block.flags;

			[fh skipBytes:6]; // Skip signature stuff

			if(block.flags&MHD_ENCRYPTVER)
			{
				encryptversion=[fh readUInt8];
NSLog(@"encryptver: %d",encryptversion);
			}
			else encryptversion=0; // ?

			if(block.flags&MHD_COMMENT)
			{
				RARBlock commentblock=[self readBlockHeader];
				[self readCommentBlock:commentblock];
				//[self skipBlock:commentblock];
			}
		}
		else if(block.type==0x7a) // newsub header
		{
		}
		else if(block.type==0x74) break; // file header

		[self skipBlock:block];
	}

	return block;
}

-(RARBlock)readFileHeaderWithBlock:(RARBlock)block
{
	if(block.flags&LHD_SPLIT_BEFORE) return [self findNextFileHeaderAfterBlock:block];

	CSHandle *fh=block.fh;
	XADSkipHandle *skip=[self skipHandle];

	off_t skipstart=[skip offsetInFile]-11+block.headersize;
	int flags=block.flags;

	off_t size=[fh readUInt32LE];
	int os=[fh readUInt8];
	uint32_t crc=[fh readUInt32LE];
	uint32_t dostime=[fh readUInt32LE];
	int version=[fh readUInt8];
	int method=[fh readUInt8];
	int namelength=[fh readUInt16LE];
	uint32_t attrs=[fh readUInt32LE];

	if(block.flags&LHD_LARGE)
	{
		block.datasize+=(off_t)[fh readUInt32LE]<<32;
		size+=(off_t)[fh readUInt32LE]<<32;
	}

	NSData *namedata=[fh readDataOfLength:namelength];

	// TODO: check crc?

	off_t datasize=block.datasize;

	off_t lastpos=block.start+block.headersize+block.datasize;
	BOOL last=(block.flags&LHD_SPLIT_AFTER)?NO:YES;
	BOOL partial=NO;

	for(;;)
	{
		[self skipBlock:block];

		@try { block=[self readBlockHeader]; }
		@catch(id e) { block=ZeroBlock; break; }

		fh=block.fh;

		if(block.type==0x74) // file header
		{
			if(last) break;
			else if(!(block.flags&LHD_SPLIT_BEFORE)) { partial=YES; break; }

			[fh skipBytes:5];
			crc=[fh readUInt32LE];
			[fh skipBytes:6];
			int namelength=[fh readUInt16LE];
			[fh skipBytes:4];

			if(block.flags&LHD_LARGE)
			{
				block.datasize+=(off_t)[fh readUInt32LE]<<32;
				[fh skipBytes:4];
			}

			NSData *currnamedata=[fh readDataOfLength:namelength];

			if(![namedata isEqual:currnamedata])
			{ // Name doesn't match, skip back to header and give up.
				[fh seekToFileOffset:block.start-(archiveflags&MHD_PASSWORD?8:0)];
				block=[self readBlockHeader];
				partial=YES;
				break;
			}

			datasize+=block.datasize;

			[skip addSkipFrom:lastpos to:block.start+block.headersize];
			lastpos=block.start+block.headersize+block.datasize;

			if(!(block.flags&LHD_SPLIT_AFTER)) last=YES;
		}
		else if(block.type==0x7a) // newsub header
		{
			NSLog(@"newsub");
		}
	}

	NSMutableDictionary *dict=[NSMutableDictionary dictionaryWithObjectsAndKeys:
		[self parseNameData:namedata flags:flags],XADFileNameKey,
		[NSNumber numberWithLongLong:size],XADFileSizeKey,
		[NSNumber numberWithLongLong:datasize],XADCompressedSizeKey,
		[NSDate XADDateWithMSDOSDateTime:dostime],XADLastModificationDateKey,

		[NSNumber numberWithInt:flags],@"RARFlags",
		[NSNumber numberWithInt:version],@"RARCompressionVersion",
		[NSNumber numberWithInt:method],@"RARCompressionMethod",
		[NSNumber numberWithUnsignedInt:crc],@"RARCRC32",
		[NSNumber numberWithInt:os],@"RAROS",
		[NSNumber numberWithUnsignedInt:attrs],@"RARAttributes",
	nil];

	if(partial) [dict setObject:[NSNumber numberWithBool:YES] forKey:XADIsCorruptedKey];

	if(flags&LHD_PASSWORD) [dict setObject:[NSNumber numberWithBool:YES] forKey:XADIsEncryptedKey];
	if((flags&LHD_WINDOWMASK)==LHD_DIRECTORY) [dict setObject:[NSNumber numberWithBool:YES] forKey:XADIsDirectoryKey];

	switch(os)
	{
		case 0: [dict setObject:[NSNumber numberWithUnsignedInt:attrs] forKey:XADDOSFileAttributesKey]; break;
		case 2: [dict setObject:[NSNumber numberWithUnsignedInt:attrs] forKey:XADWindowsFileAttributesKey]; break;
		case 3: [dict setObject:[NSNumber numberWithUnsignedInt:attrs] forKey:XADPosixPermissionsKey]; break;
	}

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
	if(methodname) [dict setObject:[self XADStringWithString:methodname] forKey:XADCompressionNameKey];

	if(method==0x30)
	{
		[dict setObject:[NSNumber numberWithLongLong:skipstart] forKey:XADDataOffsetKey];
		[dict setObject:[NSNumber numberWithLongLong:datasize] forKey:XADDataLengthKey];
	}
	else
	{
		XADRARParts *parts;

		BOOL solid;
		if(version<20) solid=(archiveflags&MHD_SOLID)&&lastcompressed;
		else solid=(flags&LHD_SOLID)!=0;

		if(solid)
		{
			if(!lastcompressed) [dict setObject:[NSNumber numberWithBool:YES] forKey:XADIsCorruptedKey];

			[dict setObject:[NSNumber numberWithBool:YES] forKey:XADIsSolidKey];
			[dict setObject:[NSValue valueWithNonretainedObject:lastnonsolid] forKey:XADFirstSolidEntryKey];
			[lastcompressed setObject:[NSValue valueWithNonretainedObject:dict] forKey:XADNextSolidEntryKey];

			parts=[lastcompressed objectForKey:@"RARParts"];
		}
		else
		{
			lastnonsolid=dict;

			parts=[[XADRARParts new] autorelease];
		}

		int part=[parts count];
		[parts addPartFrom:skipstart compressedSize:datasize uncompressedSize:size];

		[dict setObject:[NSNumber numberWithInt:part] forKey:@"RARPartIndex"];
		[dict setObject:parts forKey:@"RARParts"];

		lastcompressed=dict;
	}

	[self addEntryWithDictionary:dict retainPosition:YES];

	return block;
}

-(RARBlock)findNextFileHeaderAfterBlock:(RARBlock)block
{
	for(;;)
	{
		[self skipBlock:block];
		@try { block=[self readBlockHeader]; }
		@catch(id e) { return ZeroBlock; }

		if(block.type==0x74) return block;
	}
}

-(void)readCommentBlock:(RARBlock)block
{
	CSHandle *fh=block.fh;

	int commentsize=[fh readUInt16LE];
	int version=[fh readUInt8];
	/*int method=*/[fh readUInt8];
	/*int crc=*/[fh readUInt16LE];

	XADRARHandle *handle=[[[XADRARHandle alloc] initWithHandle:fh
	parts:[XADRARParts partWithStart:[fh offsetInFile] compressedSize:block.headersize-13
	uncompressedSize:commentsize] version:version] autorelease];

	NSData *comment=[handle readDataOfLength:commentsize];
	[self setObject:[self XADStringWithData:comment] forPropertyKey:XADCommentKey];
}

-(XADString *)parseNameData:(NSData *)data flags:(int)flags
{
	if(flags&LHD_UNICODE)
	{
		int length=[data length];
		const uint8_t *bytes=[data bytes];

		int n;
		while(n<length&&bytes[n]) n++;

		if(n==length) return [self XADStringWithData:data encoding:NSUTF8StringEncoding];
NSLog(@"absurd name!");
		int num=length-n-1;
		if(num<=1) return [self XADStringWithCString:(const char *)bytes];

		CSMemoryHandle *fh=[CSMemoryHandle memoryHandleForReadingBuffer:bytes+n+1 length:num];
		NSMutableString *str=[NSMutableString string];

		@try
		{
			int highbyte=[fh readUInt8]<<8;
			int flagbyte,flagbits=0;

			while(![fh atEndOfFile])
			{
				if(flagbits==0)
				{
					flagbyte=[fh readUInt8];
					flagbits=8;
				}

				flagbits-=2;
				switch((flagbyte>>flagbits)&3)
				{
					case 0: [str appendFormat:@"%C",[fh readUInt8]]; break;
					case 1: [str appendFormat:@"%C",highbyte+[fh readUInt8]]; break;
					case 2: [str appendFormat:@"%C",[fh readUInt16LE]]; break;
					case 3:
					{
						int len=[fh readUInt8];
						if(len&0x80)
						{
							int correction=[fh readUInt8];
							for(int i=0;i<(len&0x7f)+2;i++)
							[str appendFormat:@"%C",highbyte+(bytes[[str length]]+correction&0xff)];
						}
						else for(int i=0;i<(len&0x7f)+2;i++)
						[str appendFormat:@"%C",bytes[[str length]]];
					}
					break;
				}
			}
		}
		@catch(id e) {}

		return [self XADStringWithString:str];
	}
	else return [self XADStringWithData:data];
}




-(RARBlock)readBlockHeader
{
	CSHandle *fh=[self handle];

	if(archiveflags&MHD_PASSWORD)
	{
		NSData *salt=[fh readDataOfLength:8];

		// TODO: check for password

		fh=[[[XADRARAESHandle alloc] initWithHandle:fh
		password:[self password] salt:salt brokenHash:encryptversion<36] autorelease];
	}

	RARBlock block;

	block.fh=fh;
	block.start=[[self handle] offsetInFile];
	block.crc=[fh readUInt16LE];
	block.type=[fh readUInt8];
	block.flags=[fh readUInt16LE];
	block.headersize=[fh readUInt16LE];
	if(block.flags&RARFLAG_LONG_BLOCK) block.datasize=[fh readUInt32LE];
	else block.datasize=0;

	//if(archiveflags&MHD_PASSWORD) block.headersize+=8;

NSLog(@"block:%x flags:%x headsize:%d datasize:%qu ",block.type,block.flags,block.headersize,block.datasize);

	return block;
}

-(void)skipBlock:(RARBlock)block
{
	//if(encryptedhandle) [encryptedhandle readAndDiscardBytes:blockstart+headersize-[handle offsetInFile]];
	[[self handle] seekToFileOffset:block.start+block.headersize+block.datasize];
}




-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum
{
	if([dict objectForKey:XADIsEncryptedKey]) return nil;

	CSHandle *handle;
	if([[dict objectForKey:@"RARCompressionMethod"] intValue]==0x30)
	{
		handle=[self handleAtDataOffsetForDictionary:dict];
	}
	else
	{
		XADRARParts *parts=[dict objectForKey:@"RARParts"];

		if(currparts!=parts)
		{
			[currhandle release];
			[currparts release];

			currhandle=[[XADRARHandle alloc] initWithHandle:[self skipHandle] parts:parts
			version:[[dict objectForKey:@"RARCompressionVersion"] intValue]];
			currparts=[parts retain];
		}

		int part=[[dict objectForKey:@"RARPartIndex"] intValue];

		handle=[currhandle nonCopiedSubHandleFrom:[parts outputStartOffsetForPart:part]
		length:[parts outputSizeForPart:part]];
	}

	if(checksum) handle=[XADCRCHandle IEEECRC32HandleWithHandle:handle length:[handle fileSize]
	correctCRC:[[dict objectForKey:@"RARCRC32"] unsignedIntValue] conditioned:YES];

	return handle;
}

-(NSString *)formatName
{
	return @"RAR";
}

@end
