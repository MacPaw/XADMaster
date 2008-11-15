#import "XADGZipParser.h"
#import "CSZlibHandle.h"

@implementation XADGZipParser

+(int)requiredHeaderSize { return 3; }

+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name;
{
	const uint8_t *bytes=[data bytes];
	int length=[data length];

	if(length<3) return NO;
	if(bytes[0]==0x1f)
	{
		if((bytes[1]==0x8b||bytes[1]==0x9e) && bytes[2]==8) return YES;
		if(bytes[1]==0xa1) return YES; /* BSD-compress variant */
	}
	return NO;
}

#define GZIPF_ASCII 0x01
#define GZIPF_CONTINUATION 0x02
#define GZIPF_EXTRA 0x04
#define GZIPF_FILENAME 0x08
#define GZIPF_COMMENT 0x10
#define GZIPF_ENCRYPTED 0x20

-(void)parse
{
	CSHandle *handle=[self handle];

	uint16_t headid=[handle readUInt16BE];
	/*uint8_t method=*/[handle readUInt8];
	uint8_t flags=[handle readUInt8];
	uint32_t time=[handle readUInt32LE];
	/*uint8_t extraflags=*/[handle readUInt8];
	/*uint8_t os=*/[handle readUInt8];

	NSMutableData *filename=nil,*comment=nil;

    if(headid!=0x1fa1)
    {
		if(flags&GZIPF_CONTINUATION)
		{
			[handle skipBytes:2];
		}
		if(flags&GZIPF_EXTRA)
		{
			uint16_t len=[handle readUInt16BE]; // is this really supposed to be big-endian?
			[handle skipBytes:len];
		}
		if(flags&GZIPF_FILENAME)
		{
			filename=[NSMutableData data];
			uint8_t chr;
			while(chr=[handle readUInt8]) [filename appendBytes:&chr length:1];
		}
		if(flags&GZIPF_COMMENT)
		{
			comment=[NSMutableData data];
			uint8_t chr;
			while(chr=[handle readUInt8]) [comment appendBytes:&chr length:1];
		}
    }

	datapos=[handle offsetInFile];

	[handle seekToEndOfFile];
	[handle skipBytes:-8];
	uint32_t crc=[handle readUInt32LE];
	uint32_t size=[handle readUInt32LE];

	NSMutableDictionary *dict=[NSMutableDictionary dictionaryWithObjectsAndKeys:
		XADFileSizeKey,[NSNumber numberWithUnsignedInt:size],
		XADCompressedSizeKey,[NSNumber numberWithUnsignedLongLong:[handle offsetInFile]-datapos-8],
		XADDataOffsetKey,[NSNumber numberWithUnsignedLongLong:datapos],
		XADLastModificationDateKey,[NSDate dateWithTimeIntervalSince1970:time],
		@"GzipCRC",[NSNumber numberWithUnsignedInt:crc],
	nil];

	if(filename) [dict setObject:[self XADStringWithData:filename] forKey:XADFileNameKey];
	else
	{
		// TODO: .adz->.adf, .tgz;.tar, set no filename flag
		/*
            XAD_EXTENSION, ".gz",
            XAD_EXTENSION, ".tgz;.tar",
            XAD_EXTENSION, ".z",
            XAD_EXTENSION, ".adz;.adf",
            XAD_EXTENSION, ".tcx",
            XAD_EXTENSION, ".tzx",
		*/
		[dict setObject:[[self name] stringByDeletingPathExtension] forKey:XADFileNameKey];
	}

	if(comment) [dict setObject:[self XADStringWithData:comment] forKey:XADCommentKey];

	if(flags&GZIPF_ENCRYPTED)
	{
		//[dict setObject:[NSNumber numberWithBool:YES] forKey:XADIsEncryptedKey];
		[XADException raiseNotSupportedException];
	}

	[self addEntryWithDictionary:dict];
}

-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dictionary
{
	CSHandle *handle=[self handleForEntryWithDictionary:dictionary];

	NSNumber *enc=[dictionary objectForKey:XADIsEncryptedKey];
	if(enc&&[enc boolValue])
	{
		//uint8_t test;
		//if(flags&0x08) test=[[dict objectForKey:@"ZipLocalDate"] intValue]>>8;
		//else test=[[dict objectForKey:@"ZipCRC32"] unsignedIntValue]>>24;

		//fh=[[[XADZipCryptHandle alloc] initWithHandle:fh length:size
		//password:[self encodedPassword] testByte:test] autorelease];
	}

	return [CSZlibHandle zlibHandleWithHandle:handle];
}

-(NSString *)formatName { return @"GZip"; }

@end
