#import "XADRAR5Parser.h"
#import "XADRARInputHandle.h"
#import "XADRAR50Handle.h"
#import "XADRARAESHandle.h"
#import "XADCRCHandle.h"
#import "NSDateXAD.h"
#import "Crypto/hmac_sha256.h"
#import "Crypto/pbkdf2_hmac_sha256.h"

#define ZeroBlock ((RAR5Block){0})

static uint32_t EncryptRAR5CRC32(uint32_t crc,id context);

static BOOL IsRAR5Signature(const uint8_t *ptr)
{
	return ptr[0]=='R' && ptr[1]=='a' && ptr[2]=='r' && ptr[3]=='!' &&
	ptr[4]==0x1a && ptr[5]==0x07 && ptr[6]==0x01 && ptr[7]==0x00;
}

static uint64_t ReadRAR5VInt(CSHandle *handle)
{
	uint64_t res=0;
	int pos=0;
	for(;;)
	{
		uint8_t byte=[handle readUInt8];

		res|=(byte&0x7f)<<pos;

		if(!(byte&0x80)) return res;

		pos+=7;
	}
}

static inline BOOL IsZeroBlock(RAR5Block block) { return block.start==0; }




@implementation XADRAR5Parser

+(int)requiredHeaderSize
{
	return 8;
}

+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name
{
	const uint8_t *bytes=[data bytes];
	int length=[data length];

	if(length<8) return NO; // TODO: fix to use correct min size

	if(IsRAR5Signature(bytes)) return YES;

	return NO;
}

+(NSArray *)volumesForHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name
{
	// New naming scheme. Find the last number in the name, and look for other files
	// with the same number of digits in the same location.
	NSArray *matches;
	if((matches=[name substringsCapturedByPattern:@"^(.*[^0-9])([0-9]+)(.*)\\.rar$" options:REG_ICASE]))
	return [self scanForVolumesWithFilename:name
	regex:[XADRegex regexWithPattern:[NSString stringWithFormat:@"^%@[0-9]{%ld}%@.rar$",
		[[matches objectAtIndex:1] escapedPattern],
		(long)[(NSString *)[matches objectAtIndex:2] length],
		[[matches objectAtIndex:3] escapedPattern]] options:REG_ICASE]
	];

	return nil;
}


-(id)init
{
	if((self=[super init]))
	{
		headerkey=nil;
		cryptocache=[NSMutableDictionary new];
		solidstreams=[NSMutableArray new];
	}
	return self;
}

-(void)dealloc
{
	[headerkey release];
	[cryptocache release];
	[solidstreams release];
	[super dealloc];
}

-(void)parse
{
	currsolidstream=nil;
	totalsolidsize=0;

	NSMutableDictionary *currdict=nil;
	NSMutableArray *currparts=[NSMutableArray array];

	[[self handle] skipBytes:8];

	// TODO: Catch exceptions and emit partial files?

	@try
	{
		for(;;)
		{
			RAR5Block block=[self readBlockHeader];

			if(IsZeroBlock(block)) break;

			CSHandle *handle=block.fh;

			switch(block.type)
			{
				case 1: // Main archive header.
					[self skipBlock:block];
				break;

				case 2: // File header.
				{
					NSMutableDictionary *dict=[self readFileBlockHeader:block];

					BOOL first=!(block.flags&0x0008);
					BOOL last=!(block.flags&0x0010);

					XADPath *path1=[currdict objectForKey:XADFileNameKey];
					XADPath *path2=[dict objectForKey:XADFileNameKey];

					if(currdict && !first && [path1 isEqual:path2])
					{
						// We have a correct continuation from a previously encountered file header.
						[currdict addEntriesFromDictionary:dict];
					}
					else
					{
						// Not a continuation, or a broken continuation.
						if(currdict)
						{
							// We had a previous entry, but it did not match. Mark it
							// as corrupted and get rid of it.
							[self addEntryWithDictionary:currdict
							inputParts:currparts isCorrupted:YES];
							currparts=[NSMutableArray array];
						}

						// Set this as the current file being collected.
						currdict=dict;

						if(!first)
						{
							// This is not the first part of a new file. Mark as corrupted.
							[currdict setObject:[NSNumber numberWithBool:YES] forKey:XADIsCorruptedKey];
						}
					}

					[currparts addObject:[NSDictionary dictionaryWithObjectsAndKeys:
						[NSNumber numberWithLongLong:[self endOfBlockHeader:block]],@"Offset",
						[NSNumber numberWithLongLong:block.datasize],@"InputLength",
						[currdict objectForKey:@"RAR5CRC32"],@"CRC32",
					nil]];

					if(last)
					{
						// This is the last part of a file, so get rid of it.
						[self addEntryWithDictionary:currdict inputParts:currparts isCorrupted:NO];
						currparts=[NSMutableArray array];
						currdict=nil;
					}

					[self skipBlock:block];
				}
				break;

				//case 3: // Service header.
				//break;

				case 4: // Archive encryption header.
				{
					uint64_t version=ReadRAR5VInt(handle);
					if(version!=0) [XADException raiseNotSupportedException];

					uint64_t flags=ReadRAR5VInt(handle);
					int strength=[handle readUInt8];
					NSData *salt=[handle readDataOfLength:16];

					NSData *passcheck=nil;
					if(flags&0x0001)
					{
						passcheck=[handle readDataOfLength:8];
						//uint32_t extracrc=[handle readUInt32LE];
					}

					headerkey=[[self encryptionKeyForPassword:[self password]
					salt:salt strength:strength passwordCheck:passcheck] retain];

					[self skipBlock:block];
				}
				break;

				case 5: // End of archive header.
				{
					uint64_t flags=ReadRAR5VInt(handle);
					if(flags&0x0001)
					{
						[[self currentHandle] seekToEndOfFile];
						[[self handle] skipBytes:8];
						[headerkey release];
						headerkey=nil;
					}
					else
					{
						goto end;
					}
				}
				break;

				default:
					[self skipBlock:block];
				break;
			}
		}
	}
	@catch(id exception)
	{
		@throw;
	}

	end:
	return;
}

-(void)addEntryWithDictionary:(NSMutableDictionary *)dict
inputParts:(NSArray *)parts isCorrupted:(BOOL)iscorrupted
{
	if(iscorrupted)
	{
		[dict setObject:[NSNumber numberWithBool:YES] forKey:XADIsCorruptedKey];
	}

	// If this is not a solid file, forget the earlier solid
	// file list and start over.
	bool solid=[[dict objectForKey:XADIsSolidKey] boolValue];
	if(!solid)
	{
		currsolidstream=[NSMutableArray array];
		[solidstreams addObject:currsolidstream];
		totalsolidsize=0;
	}

	// Find the length of the file in the output stream, ignoring symlinks.
	NSNumber *length=[dict objectForKey:XADFileSizeKey];
	if([dict objectForKey:XADLinkDestinationKey]) length=[NSNumber numberWithInt:0];

	// Add the list of input parts to the current file.
	[dict setObject:parts forKey:@"RAR5InputParts"];

	// Add the current file to the solid file list.
	if([length longLongValue]!=0) [currsolidstream addObject:dict];

	// Set up solid stream paramters for the current file.
	[dict setObject:[NSNumber numberWithInteger:[solidstreams count]-1] forKey:XADSolidObjectKey];
	[dict setObject:[NSNumber numberWithLongLong:totalsolidsize] forKey:XADSolidOffsetKey];
	if(length) [dict setObject:length forKey:XADSolidLengthKey];

	// Calculate and set the total compressed size.
	off_t compsize=0;
	NSEnumerator *enumerator=[parts objectEnumerator];
	NSDictionary *part;
	while(part=[enumerator nextObject]) compsize+=[[part objectForKey:@"InputLength"] longLongValue];

	[dict setObject:[NSNumber numberWithLongLong:compsize] forKey:XADCompressedSizeKey];

	[self addEntryWithDictionary:dict];

	totalsolidsize+=[length longLongValue];
}

-(NSMutableDictionary *)readFileBlockHeader:(RAR5Block)block
{
	CSHandle *handle=block.fh;

	NSMutableDictionary *dict=[NSMutableDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithLongLong:[self endOfBlockHeader:block]],@"RAR5DataOffset",
		[NSNumber numberWithLongLong:block.datasize],@"RAR5DataLength",
	nil];

	uint64_t flags=ReadRAR5VInt(handle);
	[dict setObject:[NSNumber numberWithUnsignedLongLong:flags] forKey:@"RAR5Flags"];

	if(flags&0x0001) [dict setObject:[NSNumber numberWithBool:YES] forKey:XADIsDirectoryKey];

	uint64_t uncompsize=ReadRAR5VInt(handle);
	if(!(flags&0x0008) && !(flags&0x0001))
	[dict setObject:[NSNumber numberWithUnsignedLongLong:uncompsize] forKey:XADFileSizeKey];

	uint64_t attributes=ReadRAR5VInt(handle);
	[dict setObject:[NSNumber numberWithUnsignedLongLong:attributes] forKey:@"RAR5Attributes"];

	if(flags&0x0002)
	{
		uint32_t modification=[handle readUInt32LE];
		[dict setObject:[NSDate dateWithTimeIntervalSince1970:modification] forKey:XADLastModificationDateKey];
	}

	if(flags&0x0004)
	{
		uint32_t crc=[handle readUInt32LE];
		if(!(flags&0x0001))
		[dict setObject:[NSNumber numberWithUnsignedInt:crc] forKey:@"RAR5CRC32"];
	}

	uint64_t compinfo=ReadRAR5VInt(handle);
	if(!(flags&0x0001))
	{
		int compversion=compinfo&0x3f;
		BOOL issolid=(compinfo&0x40)>>6;
		int compmethod=(compinfo&0x380)>>7;
		int dictshift=(compinfo&0x3c00)>>10;
		uint64_t dictsize=0x20000ll<<dictshift;

		[dict setObject:[NSNumber numberWithUnsignedLongLong:compinfo] forKey:@"RAR5CompressionInformation"];
		[dict setObject:[NSNumber numberWithInt:compversion] forKey:@"RAR5CompressionVersion"];
		[dict setObject:[NSNumber numberWithBool:issolid] forKey:XADIsSolidKey];
		[dict setObject:[NSNumber numberWithInt:compmethod] forKey:@"RAR5CompressionMethod"];
		[dict setObject:[NSNumber numberWithUnsignedLongLong:dictsize] forKey:@"RAR5DictionarySize"];

		NSString *methodname=nil;
		switch(compmethod)
		{
			case 0: methodname=@"None"; break;
			case 1: methodname=[NSString stringWithFormat:@"Fastest v5.0 (%d)",compversion]; break;
			case 2: methodname=[NSString stringWithFormat:@"Fast v5.0 (%d)",compversion]; break;
			case 3: methodname=[NSString stringWithFormat:@"Normal v5.0 (%d)",compversion]; break;
			case 4: methodname=[NSString stringWithFormat:@"Good v5.0 (%d)",compversion]; break;
			case 5: methodname=[NSString stringWithFormat:@"Best v5.0 (%d)",compversion]; break;
		}
		if(methodname) [dict setObject:[self XADStringWithString:methodname] forKey:XADCompressionNameKey];
	}

	uint64_t os=ReadRAR5VInt(handle);
	[dict setObject:[NSNumber numberWithUnsignedLongLong:os] forKey:@"RAR5OS"];
	switch(os)
	{
		case 0: [dict setObject:[self XADStringWithString:@"Windows"] forKey:@"RAR5OSName"]; break;
		case 1: [dict setObject:[self XADStringWithString:@"Unix"] forKey:@"RAR5OSName"]; break;
	}

	uint64_t namelength=ReadRAR5VInt(handle);
	NSData *namedata=[handle readDataOfLength:namelength];

	[dict setObject:[self XADPathWithData:namedata encodingName:XADUTF8StringEncodingName separators:XADUnixPathSeparator]
	forKey:XADFileNameKey];

	if(block.extrasize)
	{
		off_t extraend=block.start+block.headersize;
		for(;;)
		{
			uint64_t size=ReadRAR5VInt(handle);
			off_t start=[handle offsetInFile];
			uint64_t type=ReadRAR5VInt(handle);

			switch(type)
			{
				case 0x01: // File encryption
				{
					[dict setObject:[NSNumber numberWithBool:YES] forKey:XADIsEncryptedKey];

					uint64_t version=ReadRAR5VInt(handle);
					if(version!=0) [XADException raiseNotSupportedException];

					uint64_t flags=ReadRAR5VInt(handle);
					[dict setObject:[NSNumber numberWithUnsignedLongLong:flags] forKey:@"RAR5EncryptionFlags"];

					int strength=[handle readUInt8];
					[dict setObject:[NSNumber numberWithInt:strength] forKey:@"RAR5EncryptionStrength"];

					NSData *salt=[handle readDataOfLength:16];
					[dict setObject:salt forKey:@"RAR5EncryptionSalt"];

					NSData *iv=[handle readDataOfLength:16];
					[dict setObject:iv forKey:@"RAR5EncryptionIV"];

					if(flags&0x0001)
					{
						NSData *passcheck=[handle readDataOfLength:8];
						[dict setObject:passcheck forKey:@"RAR5EncryptionCheckData"];

						uint32_t extracrc=[handle readUInt32LE];
						[dict setObject:[NSNumber numberWithUnsignedInt:extracrc] forKey:@"RAR5EncryptionExtraCRC"];
					}

					if(flags&0x0002)
					{
						[dict setObject:[NSNumber numberWithBool:YES] forKey:@"RAR5ChecksumsAreEncrypted"];
					}
				}
				break;

				case 0x02: // File hash
				{
					uint64_t type=ReadRAR5VInt(handle);
					switch(type)
					{
						case 0x00:
						{
							NSData *hash=[handle readDataOfLength:32];
							[dict setObject:hash forKey:@"RAR5BLAKE2spHash"];
						}
					}
				}
				break;

				case 0x03: // File time
				{
					uint64_t flags=ReadRAR5VInt(handle);

					if(flags&0x0002)
					{
						if(flags&0x0001)
						{
							uint32_t time=[handle readUInt32LE];
							[dict setObject:[NSDate dateWithTimeIntervalSince1970:time]
							forKey:XADLastModificationDateKey];
						}
						else
						{
							uint64_t time=[handle readUInt64LE];
							[dict setObject:[NSDate XADDateWithWindowsFileTime:time]
							forKey:XADLastModificationDateKey];
						}
					}

					if(flags&0x0004)
					{
						if(flags&0x0001)
						{
							uint32_t time=[handle readUInt32LE];
							[dict setObject:[NSDate dateWithTimeIntervalSince1970:time]
							forKey:XADCreationDateKey];
						}
						else
						{
							uint64_t time=[handle readUInt64LE];
							[dict setObject:[NSDate XADDateWithWindowsFileTime:time]
							forKey:XADCreationDateKey];
						}
					}

					if(flags&0x0008)
					{
						if(flags&0x0001)
						{
							uint32_t time=[handle readUInt32LE];
							[dict setObject:[NSDate dateWithTimeIntervalSince1970:time]
							forKey:XADLastAccessDateKey];
						}
						else
						{
							uint64_t time=[handle readUInt64LE];
							[dict setObject:[NSDate XADDateWithWindowsFileTime:time]
							forKey:XADLastAccessDateKey];
						}
					}
				}
				break;

				case 0x04: // File version
				{
					/*uint64_t flags=*/ReadRAR5VInt(handle);

					uint64_t version=ReadRAR5VInt(handle);
					[dict setObject:[NSNumber numberWithUnsignedLongLong:version] forKey:@"RAR5FileVersion"];
				}
				break;

				case 0x05: // Redirection
				{
					uint64_t type=ReadRAR5VInt(handle);
					[dict setObject:[NSNumber numberWithUnsignedLongLong:type] forKey:@"RAR5RedirectionType"];

					if(type==0x004)
					[dict setObject:[NSNumber numberWithBool:YES] forKey:XADIsHardLinkKey];

					uint64_t flags=ReadRAR5VInt(handle);
					[dict setObject:[NSNumber numberWithUnsignedLongLong:flags] forKey:@"RAR5RedirectionFlags"];

					uint64_t namelength=ReadRAR5VInt(handle);
					NSData *namedata=[handle readDataOfLength:namelength];

					[dict setObject:[self XADStringWithData:namedata encodingName:XADUTF8StringEncodingName]
					forKey:XADLinkDestinationKey];
				}
				break;

				case 0x06: // Unix owner
				{
					uint64_t flags=ReadRAR5VInt(handle);
					[dict setObject:[NSNumber numberWithUnsignedLongLong:flags] forKey:@"RAR5RedirectionFlags"];

					if(flags&0x0001)
					{
						uint64_t namelength=ReadRAR5VInt(handle);
						NSData *namedata=[handle readDataOfLength:namelength];

						[dict setObject:[self XADStringWithData:namedata]
						forKey:XADPosixUserNameKey];
					}

					if(flags&0x0002)
					{
						uint64_t namelength=ReadRAR5VInt(handle);
						NSData *namedata=[handle readDataOfLength:namelength];

						[dict setObject:[self XADStringWithData:namedata]
						forKey:XADPosixGroupNameKey];
					}

					if(flags&0x0004)
					{
						uint64_t num=ReadRAR5VInt(handle);

						[dict setObject:[NSNumber numberWithUnsignedLongLong:num]
						forKey:XADPosixUserKey];
					}

					if(flags&0x0008)
					{
						uint64_t num=ReadRAR5VInt(handle);

						[dict setObject:[NSNumber numberWithUnsignedLongLong:num]
						forKey:XADPosixUserKey];
					}
				}
				break;

				case 0x07: // Service data
				break;
			}
			[handle seekToFileOffset:start+size];
			if(start+size>=extraend) break;
		}
	}

	return dict;
}

-(RAR5Block)readBlockHeader
{
	CSHandle *fh=[self handle];
	if([fh atEndOfFile]) return ZeroBlock;

	RAR5Block block;

	block.outerstart=0;

	if(headerkey)
	{
		NSData *iv=[fh readDataOfLength:16];
		block.outerstart=[fh offsetInFile];
		fh=[[[XADRARAESHandle alloc] initWithHandle:fh RAR5Key:headerkey IV:iv] autorelease];
	}

	block.fh=fh;

	@try
	{
		block.crc=[fh readUInt32LE];
		block.headersize=ReadRAR5VInt(fh);
		block.start=[fh offsetInFile];
		block.type=ReadRAR5VInt(fh);
		block.flags=ReadRAR5VInt(fh);

		if(block.flags&0x0001) block.extrasize=ReadRAR5VInt(fh);
		else block.extrasize=0;

		if(block.flags&0x0002) block.datasize=ReadRAR5VInt(fh);
		else block.datasize=0;
	}
	@catch(id e) { return ZeroBlock; }

	block.fh=fh;

	//NSLog(@"headsize:%llu block:%llu flags:%llx extrasize:%llu datasize:%llu",block.headersize,block.type,block.flags,block.extrasize,block.datasize);

	return block;
}

-(void)skipBlock:(RAR5Block)block
{
	[[self handle] seekToFileOffset:[self endOfBlockHeader:block]+block.datasize];
}

-(off_t)endOfBlockHeader:(RAR5Block)block
{
	if(block.outerstart)
	{
		return block.outerstart+((block.start+block.headersize+15)&~15);
	}
	else
	{
		return block.start+block.headersize;
	}
}

-(NSData *)encryptionKeyForPassword:(NSString *)passwordstring salt:(NSData *)salt strength:(int)strength passwordCheck:(NSData *)check
{
	return [[self keysForPassword:passwordstring salt:salt strength:strength passwordCheck:check] objectForKey:@"Key"];
}

-(NSData *)hashKeyForPassword:(NSString *)passwordstring salt:(NSData *)salt strength:(int)strength passwordCheck:(NSData *)check
{
	return [[self keysForPassword:passwordstring salt:salt strength:strength passwordCheck:check] objectForKey:@"HashKey"];
}

-(NSDictionary *)keysForPassword:(NSString *)passwordstring salt:(NSData *)salt strength:(int)strength passwordCheck:(NSData *)check
{
	NSArray *key=[NSArray arrayWithObjects:password,salt,[NSNumber numberWithInt:strength],nil];
	NSDictionary *crypto=[cryptocache objectForKey:key];
	if(!crypto)
	{
		NSData *passworddata=[passwordstring dataUsingEncoding:NSUTF8StringEncoding];

		uint8_t DK1[32],DK2[32],DK3[32];
		PBKDF2_3([passworddata bytes],[passworddata length],[salt bytes],[salt length],
		DK1,DK2,DK3,32,1<<strength,16,16);

		if(check && [check length]==8)
		{
			const uint8_t *checkbytes=[check bytes];
			for(int i=0;i<8;i++)
			{
				if(checkbytes[i]!=(DK3[i]^DK3[i+8]^DK3[i+16]^DK3[i+24]))
				[XADException raisePasswordException];
			}
		}

		crypto=[NSDictionary dictionaryWithObjectsAndKeys:
			[NSData dataWithBytes:DK1 length:32],@"Key",
			[NSData dataWithBytes:DK2 length:32],@"HashKey",
			//[NSData dataWithBytes:DK3 length:32],@"PasswordCheck",
		nil];

		[cryptocache setObject:crypto forKey:key];
	}

	return crypto;
}

-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum
{
	// Give the caller some ahead notice if we will be using a password.
	NSNumber *encryptnum=[dict objectForKey:XADIsEncryptedKey];
	if(encryptnum && [encryptnum boolValue])
	{
		[self password];
		if(![self hasPassword]) return nil;
	}

	CSHandle *handle;
	if([[dict objectForKey:@"RAR5CompressionMethod"] intValue]==0)
	{
		handle=[self inputHandleWithDictionary:dict];

		off_t length=[[dict objectForKey:XADSolidLengthKey] longLongValue];
		if(length!=[handle fileSize]) handle=[handle nonCopiedSubHandleOfLength:length];
	}
	else
	{
		off_t length=[[dict objectForKey:XADSolidLengthKey] longLongValue];

		// Avoid 0-length files because they make trouble in solid streams.
		if(length==0) handle=[self zeroLengthHandleWithChecksum:YES];
		else handle=[self subHandleFromSolidStreamForEntryWithDictionary:dict];
	}

	if(checksum)
	{
		NSNumber *crc=[dict objectForKey:@"RAR5CRC32"];
		if(crc)
		{
			XADCRCHandle *crchandle=[XADCRCHandle IEEECRC32HandleWithHandle:handle length:[handle fileSize]
			correctCRC:[crc unsignedIntValue] conditioned:YES];

			NSNumber *checksumsencrypted=[dict objectForKey:@"RAR5ChecksumsAreEncrypted"];
			if(checksumsencrypted && [checksumsencrypted boolValue])
			{
				NSNumber *strength=[dict objectForKey:@"RAR5EncryptionStrength"];
				NSData *salt=[dict objectForKey:@"RAR5EncryptionSalt"];
				NSData *passcheck=[dict objectForKey:@"RAR5EncryptionCheckData"];

				NSData *key=[self hashKeyForPassword:[self password]
				salt:salt strength:strength.intValue passwordCheck:passcheck];

				[crchandle setCRCTransformationFunction:EncryptRAR5CRC32 context:key];
			}

			handle=crchandle;
		}

		// TODO: Add blake2sp
	}

	return handle;
}

-(CSHandle *)handleForSolidStreamWithObject:(id)obj wantChecksum:(BOOL)checksum
{
	NSNumber *index=obj;
	NSArray *stream=[solidstreams objectAtIndex:[index integerValue]];
	return [[[XADRAR50Handle alloc] initWithRARParser:self files:stream] autorelease];
}

-(CSInputBuffer *)inputBufferWithDictionary:(NSDictionary *)dict
{
	return CSInputBufferAlloc([self inputHandleWithDictionary:dict],16384);
}

-(CSHandle *)inputHandleWithDictionary:(NSDictionary *)dict
{
	NSArray *parts=[dict objectForKey:@"RAR5InputParts"];
	CSHandle *handle=[[[XADRARInputHandle alloc] initWithHandle:[self handle] parts:parts] autorelease];

	NSNumber *encryptnum=[dict objectForKey:XADIsEncryptedKey];
	if(encryptnum && [encryptnum boolValue])
	{
		NSNumber *strength=[dict objectForKey:@"RAR5EncryptionStrength"];
		NSData *salt=[dict objectForKey:@"RAR5EncryptionSalt"];
		NSData *iv=[dict objectForKey:@"RAR5EncryptionIV"];
		NSData *passcheck=[dict objectForKey:@"RAR5EncryptionCheckData"];

		NSData *key=[self encryptionKeyForPassword:[self password]
		salt:salt strength:strength.intValue passwordCheck:passcheck];

		return [[[XADRARAESHandle alloc] initWithHandle:handle
		length:[handle fileSize] RAR5Key:key IV:iv] autorelease];
	}
	else
	{
		return handle;
	}
}


-(NSString *)formatName
{
	return @"RAR 5";
}

@end


@implementation XADEmbeddedRAR5Parser

-(NSString *)formatName
{
	return @"Embedded RAR 5";
}

@end

static uint32_t EncryptRAR5CRC32(uint32_t crc,id context)
{
	NSData *key=context;

	uint8_t crcbytes[4];
	CSSetUInt32LE(crcbytes,crc^0xffffffff);

	uint8_t digest[HMAC_SHA256_DIGEST_LENGTH];

	HMAC_SHA256_CTX hmac;
	HMAC_SHA256_Init(&hmac);
	HMAC_SHA256_UpdateKey(&hmac,[key bytes],[key length]);
	HMAC_SHA256_EndKey(&hmac);

	HMAC_SHA256_StartMessage(&hmac);
	HMAC_SHA256_UpdateMessage(&hmac,crcbytes,4);
	HMAC_SHA256_EndMessage(digest,&hmac);
	HMAC_SHA256_Done(&hmac);

	uint32_t newcrc=0;
	for(int i=0;i<sizeof(digest);i++) newcrc^=digest[i]<<((i&3)*8);

	return newcrc^0xffffffff;
}
