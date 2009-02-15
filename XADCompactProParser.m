#import "XADCompactProParser.h"
#import "XADCompactProRLEHandle.h"
#import "XADCompactProLZHHandle.h"
#import "XADException.h"
#import "XADCRCHandle.h"
#import "Paths.h"
#import "NSDateXAD.h"

@implementation XADCompactProParser

+(int)requiredHeaderSize { return 8; }

+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name
{
	const uint8_t *bytes=[data bytes];
	int length=[data length];

	// TODO: better filetype detector!
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
	int commentlen=[fh readUInt8];

	if(commentlen)
	{
		NSData *comment=[fh readDataOfLength:commentlen];
		[self setObject:[self XADStringWithData:comment] forPropertyKey:XADCommentKey];
	}

	[self parseDirectoryWithNameData:nil numberOfEntries:numentries];

	// TODO: handle comment
}

-(void)parseDirectoryWithNameData:(NSData *)parentdata numberOfEntries:(int)numentries
{
	CSHandle *fh=[self handle];

	while(numentries)
	{
		int namelen=[fh readUInt8];
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
	}
}

-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum
{
	CSHandle *handle=[self handleAtDataOffsetForDictionary:dict];
	off_t size=[[dict objectForKey:XADFileSizeKey] longLongValue];

	if([[dict objectForKey:@"CompactProLZH"] boolValue])
	handle=[[[XADCompactProLZHHandle alloc] initWithHandle:handle blockSize:0x1fff0] autorelease];

	handle=[[[XADCompactProRLEHandle alloc] initWithHandle:handle length:size] autorelease];

	NSNumber *crc=[dict objectForKey:@"CompactProCRC32"];
	if(checksum&&crc)
	handle=[XADCRCHandle IEEECRC32HandleWithHandle:handle length:size correctCRC:~[crc unsignedIntValue] conditioned:YES];

	return handle;
}

-(NSString *)formatName { return @"Compact Pro"; }

@end
