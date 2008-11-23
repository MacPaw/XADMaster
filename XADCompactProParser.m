#import "XADCompactProParser.h"
#import "XADEndianAccess.h"
#import "XADException.h"
#import "NSDateXAD.h"

// TODO: actually implement this format!

@implementation XADCompactProParser

+(int)requiredHeaderSize { return 8; }

+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name
{
	const uint8_t *bytes=[data bytes];
	int length=[data length];

	return length>=8&&bytes[0]==1&&[[[name pathExtension] lowercaseString] isEqual:@"cpt"];
}

-(void)parse
{
	CSHandle *fh=[self handle];

	/*int marker=*/[fh readUInt8];
	/*int volume=*/[fh readUInt8];
	/*int xmagic=*/[fh readUInt16BE];
	uint32_t offset=[fh readUInt32BE];

	[fh seekToFileOffset:offset];

	/*uint32_t headcrc=*/[fh readUInt32BE];
	int numentries=[fh readUInt16BE];
	/*int something2=*/[fh readUInt8];

	for(int i=0;i<numentries;i++)
	{
		int namelen=[fh readUInt8];
		NSData *namedata=[fh readDataOfLength:namelen];
		/*int something=*/[fh readUInt8];
//		int foldersize=[fh readUInt16BE];
//		int volume=[fh readUInt8];
		uint32_t fileoffs=[fh readUInt32BE];
		uint32_t type=[fh readUInt32BE];
		uint32_t creator=[fh readUInt32BE];
		uint32_t creationdate=[fh readUInt32BE];
		uint32_t modificationdate=[fh readUInt32BE];
		int finderflags=[fh readUInt16BE];
		uint32_t crc=[fh readUInt32BE];
		int flags=[fh readUInt16BE];
		uint32_t datalength=[fh readUInt32BE];
		uint32_t resourcelength=[fh readUInt32BE];
		uint32_t datacomplen=[fh readUInt32BE];
		uint32_t resourcecomplen=[fh readUInt32BE];

		off_t next=[fh offsetInFile];

		if(datalength)
		{
			NSMutableDictionary *dict=[NSMutableDictionary dictionaryWithObjectsAndKeys:
				[self XADStringWithData:namedata],XADFileNameKey,
				[NSNumber numberWithUnsignedInt:datalength],XADFileSizeKey,
				[NSNumber numberWithUnsignedInt:datacomplen],XADCompressedSizeKey,
				[NSDate XADDateWithTimeIntervalSince1904:modificationdate],XADLastModificationDateKey,
				[NSDate XADDateWithTimeIntervalSince1904:creationdate],XADCreationDateKey,
				[NSNumber numberWithUnsignedInt:type],XADFileTypeKey,
				[NSNumber numberWithUnsignedInt:creator],XADFileCreatorKey,
				[NSNumber numberWithInt:finderflags],XADFinderFlagsKey,

				[NSNumber numberWithLongLong:fileoffs],XADDataOffsetKey,
				[NSNumber numberWithInt:flags],@"CompactProFlags",
				[NSNumber numberWithUnsignedInt:crc],@"CompactProCRC32",
			nil];

			[self addEntryWithDictionary:dict];
		}

		if(resourcelength)
		{
			NSMutableDictionary *dict=[NSMutableDictionary dictionaryWithObjectsAndKeys:
				[self XADStringWithData:namedata],XADFileNameKey,
				[NSNumber numberWithUnsignedInt:resourcelength],XADFileSizeKey,
				[NSNumber numberWithUnsignedInt:resourcecomplen],XADCompressedSizeKey,
				[NSDate XADDateWithTimeIntervalSince1904:modificationdate],XADLastModificationDateKey,
				[NSDate XADDateWithTimeIntervalSince1904:creationdate],XADCreationDateKey,
				[NSNumber numberWithUnsignedInt:type],XADFileTypeKey,
				[NSNumber numberWithUnsignedInt:creator],XADFileCreatorKey,
				[NSNumber numberWithInt:finderflags],XADFinderFlagsKey,

				[NSNumber numberWithBool:YES],XADIsResourceForkKey,
				[NSNumber numberWithLongLong:fileoffs+datacomplen],XADDataOffsetKey,
				[NSNumber numberWithInt:flags],@"CompactProFlags",
				[NSNumber numberWithUnsignedInt:crc],@"CompactProCRC32",
			nil];

			[self addEntryWithDictionary:dict];
		}

		[fh seekToFileOffset:next];
	}
}

-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum
{
	return nil;
}

-(NSString *)formatName { return @"Compact Pro"; }

@end
