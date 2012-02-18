#import "XADStuffItSplitParser.h"
#import "CSMultiHandle.h"
#import "CSFileHandle.h"
#import "CRC.h"

@implementation XADStuffItSplitParser

+(int)requiredHeaderSize { return 100; }

+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name
{
	const uint8_t *bytes=[data bytes];
	int length=[data length];

	if(length<100) return NO;
	if(bytes[0]!=0xb0) return NO;
	if(bytes[1]!=0x56) return NO;
	if(bytes[2]!=0x00) return NO; // Assume there are less than 256 parts.
	if(bytes[4]==0) return NO;
	if(bytes[4]>63) return NO;
	for(int i=0;i<bytes[4];i++) if(bytes[5+i]==0) return NO;

	return YES;
}

+(NSArray *)volumesForHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name
{
	const uint8_t *bytes=[data bytes];

	NSString *basename=[[name lastPathComponent] stringByDeletingPathExtension];

	NSString *dirname=[name stringByDeletingLastPathComponent];
	#if MAC_OS_X_VERSION_MIN_REQUIRED>=1050
	NSArray *dircontents=[[NSFileManager defaultManager] contentsOfDirectoryAtPath:dirname error:NULL];
	#else
	NSArray *dircontents=[[NSFileManager defaultManager] directoryContentsAtPath:dirname];
	#endif

	NSString *parts[256]={nil};

	NSEnumerator *enumerator=[dircontents objectEnumerator];
	NSString *filename;
	while((filename=[enumerator nextObject]))
	{
		if(![filename hasPrefix:basename]) continue;

		NSString *fullpath=[dirname stringByAppendingPathComponent:filename];
		@try
		{
			CSFileHandle *filehandle=[CSFileHandle fileHandleForReadingAtPath:fullpath];
			uint8_t header[100];
			int actual=[filehandle readAtMost:sizeof(header) toBuffer:header];
			if(actual<sizeof(header)) continue;
			if(header[0]!=0xb0) continue;
			if(header[1]!=0x56) continue;
			if(header[2]!=0x00) continue;
			if(header[4]!=bytes[4]) continue;
			if(memcmp(&header[5],&header[5],header[4])!=0) continue;
			if(memcmp(&header[68],&header[68],28)!=0) continue;

			int partnum=header[3];
			parts[partnum]=fullpath;

			[filehandle close];
		}
		@catch(id e) {}
	}

	NSMutableArray *volumes=[NSMutableArray array];
	for(int i=1;i<256;i++)
	{
		if(!parts[i]) break;
		[volumes addObject:parts[i]];
	}

	return volumes;
}



-(void)parse
{
	CSHandle *fh=[self handle];

	NSArray *handles=[self volumes];
	if(!handles) handles=[NSArray arrayWithObject:fh];

	XADSkipHandle *sh=[self skipHandle];
	off_t curroffset=0;
	off_t size=0;

	NSEnumerator *enumerator=[handles objectEnumerator];
	CSHandle *handle;
	while((handle=[enumerator nextObject]))
	{
		[sh addSkipFrom:curroffset length:100];
		off_t volumesize=[handle fileSize];
		curroffset+=volumesize;
		size+=volumesize-100;
	}

	[fh skipBytes:4];
	int namelength=[fh readUInt8];
	NSData *namedata=[fh readDataOfLength:namelength];

	[fh seekToFileOffset:68];
	uint32_t type=[fh readUInt32BE];
	uint32_t creator=[fh readUInt32BE];

	NSMutableDictionary *dict=[NSMutableDictionary dictionaryWithObjectsAndKeys:
		[self XADPathWithData:namedata separators:XADNoPathSeparator],XADFileNameKey,
		[NSNumber numberWithLongLong:size],XADFileSizeKey,
		[NSNumber numberWithLongLong:curroffset],XADCompressedSizeKey,
		[NSNumber numberWithLongLong:0],XADSkipOffsetKey,
		[NSNumber numberWithLongLong:size],XADSkipLengthKey,
		[NSNumber numberWithUnsignedInt:type],XADFileTypeKey,
		[NSNumber numberWithUnsignedInt:creator],XADFileCreatorKey,
	nil];

	const uint8_t *namebytes=[namedata bytes];

	if(namelength>4)
	if(namebytes[namelength-4]=='.')
	if(namebytes[namelength-3]=='s'||namebytes[namelength-3]=='S')
	if(namebytes[namelength-2]=='i'||namebytes[namelength-2]=='I')
	if(namebytes[namelength-1]=='t'||namebytes[namelength-1]=='T')
	[dict setObject:[NSNumber numberWithBool:YES] forKey:XADIsArchiveKey];

	if(namelength>4)
	if(namebytes[namelength-4]=='.')
	if(namebytes[namelength-3]=='s'||namebytes[namelength-3]=='S')
	if(namebytes[namelength-2]=='e'||namebytes[namelength-2]=='E')
	if(namebytes[namelength-1]=='a'||namebytes[namelength-1]=='A')
	[dict setObject:[NSNumber numberWithBool:YES] forKey:XADIsArchiveKey];

	[self addEntryWithDictionary:dict];
}

-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum
{
	return [self handleAtDataOffsetForDictionary:dict];
}

-(NSString *)formatName { return @"StuffIt split file"; }

@end
