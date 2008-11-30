#import "XADALZipParser.h"
#import "XADDeflateHandle.h"
#import "XADException.h"
#import "Checksums.h"
#import "NSDateXAD.h"

@implementation XADALZipParser

+(int)requiredHeaderSize { return 8; }

+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name
{
	const uint8_t *bytes=[data bytes];
	int length=[data length];

	return length>=8&&bytes[0]=='A'&&bytes[0]=='L'&&bytes[0]=='Z'&&bytes[0]==1&&bytes[7]==0;
}

-(void)parse
{
	CSHandle *fh=[self handle];

	[fh skipBytes:8];

	for(;;)
	{
		uint32_t signature=[fh readID];

		if(signature=='BLZ\001')
		{
			int namelen=[fh readUInt16LE];
			int attrs=[fh readUInt8];
			uint32_t dostime=[fh readUInt32LE];
			int flags=[fh readUInt8];
			[fh skipBytes:1];

			int sizebytes=flags>>4;
			if(sizebytes)
			{
			}
		NSData *namedata=[fh readDataOfLength:namelen&0x7f];
		NSData *pathdata=XADBuildMacPathWithData(parentdata,namedata);

		if(namelen&0x80)
		{
			int entries=[fh readUInt16BE];

			NSMutableDictionary *dict=[NSMutableDictionary dictionaryWithObjectsAndKeys:
				[self XADStringWithData:pathdata],XADFileNameKey,
				[NSNumber numberWithBool:YES],XADIsDirectoryKey,
			nil];

			[self addEntryWithDictionary:dict retainPosition:YES];

			[self parseDirectoryWithNameData:namedata numberOfEntries:entries];

			numentries-=entries+1;
		}
		else
		{
			int volume=[fh readUInt8];
			uint32_t fileoffs=[fh readUInt32BE];
			uint32_t type=[fh readUInt32BE];
			uint32_t creator=[fh readUInt32BE];
			uint32_t creationdate=[fh readUInt32BE];
			uint32_t modificationdate=[fh readUInt32BE];
			int finderflags=[fh readUInt16BE];
			uint32_t crc=[fh readUInt32BE];
			int flags=[fh readUInt16BE]; // TODO: bit 0 means encryption
			uint32_t resourcelength=[fh readUInt32BE];
			uint32_t datalength=[fh readUInt32BE];
			uint32_t resourcecomplen=[fh readUInt32BE];
			uint32_t datacomplen=[fh readUInt32BE];

			off_t next=[fh offsetInFile];

			if(resourcelength)
			{
				NSString *crckey;
				if(datalength) crckey=@"CompactProSharedCRC32";
				else crckey=@"CompactProCRC32";

				NSMutableDictionary *dict=[NSMutableDictionary dictionaryWithObjectsAndKeys:
					[self XADStringWithData:pathdata],XADFileNameKey,
					[NSNumber numberWithUnsignedInt:resourcelength],XADFileSizeKey,
					[NSNumber numberWithUnsignedInt:resourcecomplen],XADCompressedSizeKey,
					[NSDate XADDateWithTimeIntervalSince1904:modificationdate],XADLastModificationDateKey,
					[NSDate XADDateWithTimeIntervalSince1904:creationdate],XADCreationDateKey,
					[NSNumber numberWithUnsignedInt:type],XADFileTypeKey,
					[NSNumber numberWithUnsignedInt:creator],XADFileCreatorKey,
					[NSNumber numberWithInt:finderflags],XADFinderFlagsKey,
					[self XADStringWithString:flags&2?@"LZH+RLE":@"RLE"],XADCompressionNameKey,

					[NSNumber numberWithBool:YES],XADIsResourceForkKey,
					[NSNumber numberWithUnsignedInt:resourcecomplen],XADDataLengthKey,
					[NSNumber numberWithLongLong:fileoffs],XADDataOffsetKey,
					[NSNumber numberWithBool:flags&2?YES:NO],@"CompactProLZH",
					[NSNumber numberWithInt:flags],@"CompactProFlags",
					[NSNumber numberWithUnsignedInt:crc],crckey,
					[NSNumber numberWithUnsignedInt:volume],@"CompactProVolume",
				nil];

				[self addEntryWithDictionary:dict];
			}

			if(datalength||resourcelength==0)
			{
				NSString *crckey;
				if(resourcelength) crckey=@"CompactProSharedCRC32";
				else crckey=@"CompactProCRC32";

				NSMutableDictionary *dict=[NSMutableDictionary dictionaryWithObjectsAndKeys:
					[self XADStringWithData:pathdata],XADFileNameKey,
					[NSNumber numberWithUnsignedInt:datalength],XADFileSizeKey,
					[NSNumber numberWithUnsignedInt:datacomplen],XADCompressedSizeKey,
					[NSDate XADDateWithTimeIntervalSince1904:modificationdate],XADLastModificationDateKey,
					[NSDate XADDateWithTimeIntervalSince1904:creationdate],XADCreationDateKey,
					[NSNumber numberWithUnsignedInt:type],XADFileTypeKey,
					[NSNumber numberWithUnsignedInt:creator],XADFileCreatorKey,
					[NSNumber numberWithInt:finderflags],XADFinderFlagsKey,
					[self XADStringWithString:flags&4?@"LZH+RLE":@"RLE"],XADCompressionNameKey,

					[NSNumber numberWithLongLong:fileoffs+resourcecomplen],XADDataOffsetKey,
					[NSNumber numberWithUnsignedInt:datacomplen],XADDataLengthKey,
					[NSNumber numberWithBool:flags&4?YES:NO],@"CompactProLZH",
					[NSNumber numberWithInt:flags],@"CompactProFlags",
					[NSNumber numberWithUnsignedInt:crc],crckey,
					[NSNumber numberWithUnsignedInt:volume],@"CompactProVolume",
				nil];

				[self addEntryWithDictionary:dict];
			}

			[fh seekToFileOffset:next];
			numentries--;
		}
		else if(signature=='CLZ\001') break;
		else [XADException raiseIllegalDataException];
	}
}

-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum
{
	CSHandle *handle=[self handleAtDataOffsetForDictionary:dict];
	off_t size=[[dict objectForKey:XADFileSizeKey] longLongValue];

	switch([[dict objectForKey:@"ALZipCompressionMethod"] intValue])
	{
		case 0: break; // No compression
		//case 1: handle=[[[XADBzip2Handle alloc]
		case 2: handle=[[[XADDeflateHandle alloc] initWithHandle:handle length:size] autorelease]; break;
		//case 3:
		default: return nil;
	}

	if(checksum) handle=[XADCRCHandle IEEECRC32HandleWithHandle:handle length:size
	correctCRC:[[dict objectForKey:@"ALZipCRC32"] unsignedIntValue] conditioned:YES];

	return handle;
}

-(NSString *)formatName { return @"ALZip"; }

@end
