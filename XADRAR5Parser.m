#import "XADRAR5Parser.h"
#import "NSDateXAD.h"

typedef struct RAR5Block
{
	uint32_t crc;
	uint64_t headersize,type,flags;
	uint64_t extrasize,datasize;
	off_t start;
	CSHandle *fh;
} RAR5Block;

#define ZeroBlock ((RAR5Block){0})

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
/*	if([data length]<12) return nil;
	const uint8_t *header=[data bytes];
	uint16_t flags=CSUInt16LE(&header[10]);

	// Don't bother looking for volumes if it the volume bit is not set.
	if(!(flags&1)) return nil;

	// Check the old/new naming bit.
	if(flags&0x10)
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
	}

	// Old naming scheme. Just look for rar/r01/s01/... files.
	NSArray *matches;
	if((matches=[name substringsCapturedByPattern:@"^(.*)\\.(rar|[r-z][0-9]{2})$" options:REG_ICASE]))
	{
		return [self scanForVolumesWithFilename:name
		regex:[XADRegex regexWithPattern:[NSString stringWithFormat:@"^%@\\.(rar|[r-z][0-9]{2})$",
			[[matches objectAtIndex:1] escapedPattern]] options:REG_ICASE]
		firstFileExtension:@"rar"];
	}*/

	return nil;
}


-(id)init
{
	if((self=[super init]))
	{
		headersalt=nil;
//		keys=nil;
	}
	return self;
}

-(void)dealloc
{
	[headersalt release];
//	[keys release];
	[super dealloc];
}

-(void)setPassword:(NSString *)newpassword
{
	// Make sure to clear key cache if password changes.
//	[keys release];
//	keys=nil;
	[super setPassword:newpassword];
}

-(void)parse
{
	CSHandle *handle=[self handle];

	[handle skipBytes:8];

	RAR5Block block=[self readBlockHeader];

	if(block.type!=1)
	{
		[XADException raiseIllegalDataException];
	}

	[self skipBlock:block];

	for(;;)
	{
		RAR5Block block=[self readBlockHeader];

		if(IsZeroBlock(block)) break;

		switch(block.type)
		{
			case 1:
				NSLog(@"Archive header");
			break;

			case 2:
			{

				NSMutableDictionary *dict=[NSMutableDictionary dictionaryWithObjectsAndKeys:
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
					int compdictsize=(compinfo&0x3c00)>>10;
					[dict setObject:[NSNumber numberWithUnsignedLongLong:compinfo] forKey:@"RAR5CompressionInformation"];
					[dict setObject:[NSNumber numberWithInt:compversion] forKey:@"RAR5CompressionVersion"];
					[dict setObject:[NSNumber numberWithBool:issolid] forKey:XADIsSolidKey];
					[dict setObject:[NSNumber numberWithInt:compmethod] forKey:@"RAR5CompressionMethod"];
					[dict setObject:[NSNumber numberWithInt:compdictsize] forKey:@"RAR5CompressionDictionarySize"];
					// TODO: Compression algorithm name
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

								if(flags&0x0002)
								{
									NSData *passcheck=[handle readDataOfLength:8];
									[dict setObject:passcheck forKey:@"RAR5EncryptionCheckData"];

									uint32_t extracrc=[handle readUInt32LE];
									[dict setObject:[NSNumber numberWithUnsignedInt:extracrc] forKey:@"RAR5EncryptionExtraCRC"];
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

				[self addEntryWithDictionary:dict];
			}
			break;

			case 4:
			{
				uint64_t version=ReadRAR5VInt(handle);
				if(version!=0) [XADException raiseNotSupportedException];

				uint64_t flags=ReadRAR5VInt(handle);
				int strength=[handle readUInt8];
				headersalt=[handle readDataOfLength:16];

				NSLog(@"crypto %llx %d %@",flags,strength,headersalt);

				if(flags&0x0001)
				{
					NSData *passcheck=[handle readDataOfLength:8];
					uint32_t extracrc=[handle readUInt32LE];
					NSLog(@"pass check %@ %08x",passcheck,extracrc);
				}

				[XADException raiseNotSupportedException];

				[self skipBlock:block];
				block=[self readBlockHeader];
			}
		}

		[self skipBlock:block];
	}
}

-(RAR5Block)readBlockHeader
{
	CSHandle *fh=[self handle];
	if([fh atEndOfFile]) return ZeroBlock;

	RAR5Block block;

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

/*	if(archiveflags&MHD_PASSWORD)
	{
		NSData *salt=[fh readDataOfLength:8];
		fh=[[[XADRARAESHandle alloc] initWithHandle:fh key:[self keyForSalt:salt]] autorelease];
	}*/

	block.fh=fh;

	NSLog(@"headsize:%llu block:%llu flags:%llx extrasize:%llu datasize:%llu",block.headersize,block.type,block.flags,block.extrasize,block.datasize);

	return block;
}

-(void)skipBlock:(RAR5Block)block
{
	[[self handle] seekToFileOffset:block.start+block.headersize+block.datasize];
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
