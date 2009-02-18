#import "XADLHAParser.h"
#import "XADLHAStaticHandle.h"
#import "XADLHADynamicHandle.h"
#import "XADLArcHandles.h"
#import "XADCRCHandle.h"
#import "NSDateXAD.h"


@implementation XADLHAParser

+(int)requiredHeaderSize { return 7; }

+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name
{
	const uint8_t *bytes=[data bytes];
	int length=[data length];

	if(length<7) return NO;

	if(bytes[2]=='-'&&bytes[3]=='l'&&bytes[4]=='h'&&bytes[6]=='-')
	{
		if(bytes[5]=='0'||bytes[5]=='1') return YES; // uncompressed and old
		if(bytes[5]=='4'||bytes[5]=='5'||bytes[5]=='6'||bytes[5]=='7') return YES; // new
		if(bytes[5]=='d') return YES; // directory
	}

	if(bytes[2]=='-'&&bytes[3]=='l'&&bytes[4]=='z'&&bytes[6]=='-')
	{
		if(bytes[5]=='0'||bytes[5]=='4'||bytes[5]=='5') return YES;
	}

	return NO;
}

-(void)parse
{
	CSHandle *fh=[self handle];

	for(;;)
	{
		off_t start=[fh offsetInFile];

		int firstword;
		@try { firstword=[fh readInt16LE]; }
		@catch(id e) { break; }

		if((firstword&0xff)==0) break;

		uint8_t method[5];
		[fh readBytes:5 toBuffer:method];

		uint32_t compsize=[fh readUInt32LE];
		uint32_t size=[fh readUInt32LE];
		uint32_t time=[fh readUInt32LE];

		int dosattrs=[fh readUInt8];
		int level=[fh readUInt8];

		NSString *compname=[[[NSString alloc] initWithBytes:method length:5 encoding:NSISOLatin1StringEncoding] autorelease];

		NSMutableDictionary *dict=[NSMutableDictionary dictionaryWithObjectsAndKeys:
			[NSNumber numberWithUnsignedInt:size],XADFileSizeKey,
			[self XADStringWithString:compname],XADCompressionNameKey,
			[NSNumber numberWithInt:level],@"LHAHeaderLevel",
		nil];

		uint32_t headersize;
		int os;

		if(level==0||level==1)
		{
			headersize=(firstword&0xff)+2;

			[dict setObject:[NSDate XADDateWithMSDOSDateTime:time] forKey:XADLastModificationDateKey];
			[dict setObject:[NSNumber numberWithInt:dosattrs] forKey:XADDOSFileAttributesKey];

			int namelen=[fh readUInt8];
			[dict setObject:[fh readDataOfLength:namelen] forKey:@"LHAHeaderFileNameData"];

			int crc=[fh readUInt16LE];
			[dict setObject:[NSNumber numberWithInt:crc] forKey:@"LHACRC16"];

			if(level==1)
			{
				os=[fh readUInt8];
				[dict setObject:[NSNumber numberWithInt:os] forKey:@"LHAOS"];

				for(;;)
				{
					int extsize=[fh readUInt16LE];
					if(extsize==0) break;
					headersize+=extsize;
					compsize-=extsize;

					[self parseExtendedForDictionary:dict size:extsize-2];
				}
			}
		}
		else if(level==2)
		{
			headersize=firstword;

			[dict setObject:[NSDate dateWithTimeIntervalSince1970:time] forKey:XADLastModificationDateKey];

			int crc=[fh readUInt16LE];
			[dict setObject:[NSNumber numberWithInt:crc] forKey:@"LHACRC16"];

			os=[fh readUInt8];
			[dict setObject:[NSNumber numberWithInt:os] forKey:@"LHAOS"];

			for(;;)
			{
				int extsize=[fh readUInt16LE];
				if(extsize==0) break;
				[self parseExtendedForDictionary:dict size:extsize-2];
			}
		}
		else if(level==3)
		{
			if(firstword!=4) [XADException raiseNotSupportedException];

			[dict setObject:[NSDate dateWithTimeIntervalSince1970:time] forKey:XADLastModificationDateKey];

			int crc=[fh readUInt16LE];
			[dict setObject:[NSNumber numberWithInt:crc] forKey:@"LHACRC16"];

			os=[fh readUInt8];
			[dict setObject:[NSNumber numberWithInt:os] forKey:@"LHAOS"];

			headersize=[fh readUInt32LE];

			for(;;)
			{
				int extsize=[fh readUInt32LE];
				if(extsize==0) break;
				[self parseExtendedForDictionary:dict size:extsize-4];
			}
		}
		else [XADException raiseIllegalDataException];

		[dict setValue:[NSNumber numberWithUnsignedInt:compsize] forKey:XADCompressedSizeKey];
		[dict setValue:[NSNumber numberWithUnsignedInt:compsize] forKey:XADDataLengthKey];
		[dict setValue:[NSNumber numberWithLongLong:start+headersize] forKey:XADDataOffsetKey];

		if(memcmp(method,"-lhd-",5)==0) [dict setValue:[NSNumber numberWithBool:YES] forKey:XADIsDirectoryKey];

		NSData *filenamedata=[dict objectForKey:@"LHAExtFileNameData"];
		if(!filenamedata) filenamedata=[dict objectForKey:@"LHAHeaderFileNameData"];
		NSData *directorydata=[dict objectForKey:@"LHAExtDirectoryData"];
		if(filenamedata||directorydata)
		{
			int filenamesize=0,directorysize=0;
			if(filenamedata) filenamesize=[filenamedata length];
			if(directorydata) directorysize=[directorydata length];

			int size=filenamesize+directorysize;
			uint8_t namebuf[size];

			if(directorydata) memcpy(namebuf,[directorydata bytes],directorysize);
			if(filenamedata) memcpy(namebuf+directorysize,[filenamedata bytes],filenamesize);

			for(int i=0;i<size;i++) if(namebuf[i]==0xff) namebuf[i]='/';

			[dict setObject:[self XADStringWithBytes:namebuf length:size] forKey:XADFileNameKey];
		}

		if(os=='m') [dict setObject:[NSNumber numberWithBool:YES] forKey:XADMightBeMacBinaryKey];

		[self addEntryWithDictionary:dict];

		[fh seekToFileOffset:start+headersize+compsize];
	}
}

-(void)parseExtendedForDictionary:(NSMutableDictionary *)dict size:(int)size
{
	CSHandle *fh=[self handle];
	off_t nextpos=[fh offsetInFile]+size;

	switch([fh readUInt8])
	{
		case 0x01:
			[dict setObject:[fh readDataOfLength:size-1] forKey:@"LHAExtFileNameData"];
		break;

		case 0x02:
			[dict setObject:[fh readDataOfLength:size-1] forKey:@"LHAExtDirectoryData"];
		break;

		case 0x3f:
		case 0x71:
			[dict setObject:[self XADStringWithData:[fh readDataOfLength:size-1]] forKey:XADCommentKey];
		break;

		case 0x40:
			[dict setObject:[NSNumber numberWithInt:[fh readUInt16LE]] forKey:XADDOSFileAttributesKey];
		break;

		case 0x41:
			[dict setObject:[NSDate XADDateWithWindowsFileTimeLow:[fh readUInt32LE]
			high:[fh readUInt32LE]] forKey:XADCreationDateKey];
			[dict setObject:[NSDate XADDateWithWindowsFileTimeLow:[fh readUInt32LE]
			high:[fh readUInt32LE]] forKey:XADLastModificationDateKey];
			[dict setObject:[NSDate XADDateWithWindowsFileTimeLow:[fh readUInt32LE]
			high:[fh readUInt32LE]] forKey:XADLastAccessDateKey];
		break;

		case 0x42:
			// 64-bit file sizes
			[XADException raiseNotSupportedException];
		break;

		case 0x50:
			[dict setObject:[NSNumber numberWithInt:[fh readUInt16LE]] forKey:XADPosixPermissionsKey];
		break;

		case 0x51:
			[dict setObject:[NSNumber numberWithInt:[fh readUInt16LE]] forKey:XADPosixGroupKey];
			[dict setObject:[NSNumber numberWithInt:[fh readUInt16LE]] forKey:XADPosixUserKey];
		break;

		case 0x52:
			[dict setObject:[self XADStringWithData:[fh readDataOfLength:size-1]] forKey:XADPosixGroupNameKey];
		break;

		case 0x53:
			[dict setObject:[self XADStringWithData:[fh readDataOfLength:size-1]] forKey:XADPosixUserNameKey];
		break;

		case 0x54:
			[dict setObject:[NSDate dateWithTimeIntervalSince1970:[fh readUInt32LE]] forKey:XADLastModificationDateKey];
		break;

		case 0x7f:
			[dict setObject:[NSNumber numberWithInt:[fh readUInt16LE]] forKey:XADDOSFileAttributesKey];
			[dict setObject:[NSNumber numberWithInt:[fh readUInt16LE]] forKey:XADPosixPermissionsKey];
			[dict setObject:[NSNumber numberWithInt:[fh readUInt16LE]] forKey:XADPosixGroupKey];
			[dict setObject:[NSNumber numberWithInt:[fh readUInt16LE]] forKey:XADPosixUserKey];
			[dict setObject:[NSDate dateWithTimeIntervalSince1970:[fh readUInt32LE]] forKey:XADCreationDateKey];
			[dict setObject:[NSDate dateWithTimeIntervalSince1970:[fh readUInt32LE]] forKey:XADLastModificationDateKey];
		break;

		// case 0xc4: // compressed comment, -lh5- 4096
		// case 0xc5: // compressed comment, -lh5- 8192
		// case 0xc6: // compressed comment, -lh5- 16384
		// case 0xc7: // compressed comment, -lh5- 32768
		// case 0xc8: // compressed comment, -lh5- 65536

		case 0xff:
			[dict setObject:[NSNumber numberWithInt:[fh readUInt32LE]] forKey:XADPosixPermissionsKey];
			[dict setObject:[NSNumber numberWithInt:[fh readUInt32LE]] forKey:XADPosixGroupKey];
			[dict setObject:[NSNumber numberWithInt:[fh readUInt32LE]] forKey:XADPosixUserKey];
			[dict setObject:[NSDate dateWithTimeIntervalSince1970:[fh readUInt32LE]] forKey:XADCreationDateKey];
			[dict setObject:[NSDate dateWithTimeIntervalSince1970:[fh readUInt32LE]] forKey:XADLastModificationDateKey];
		break;
	}

	[fh seekToFileOffset:nextpos];
}


-(CSHandle *)rawHandleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum
{
	CSHandle *handle=[self handleAtDataOffsetForDictionary:dict];
	off_t size=[[dict objectForKey:XADFileSizeKey] longLongValue];
	NSString *method=[[dict objectForKey:XADCompressionNameKey] string];
	int crc=[[dict objectForKey:@"LHACRC16"] intValue];

	if([method isEqual:@"-lh0-"])
	{
		// no compression, do nothing
	}
	else if([method isEqual:@"-lh1-"])
	{
		handle=[[[XADLHADynamicHandle alloc] initWithHandle:handle length:size] autorelease];
	}
	else if([method isEqual:@"-lh4-"])
	{
		handle=[[[XADLHAStaticHandle alloc] initWithHandle:handle length:size windowBits:12] autorelease];
	}
	else if([method isEqual:@"-lh5-"])
	{
		handle=[[[XADLHAStaticHandle alloc] initWithHandle:handle length:size windowBits:13] autorelease];
	}
	else if([method isEqual:@"-lh6-"])
	{
		handle=[[[XADLHAStaticHandle alloc] initWithHandle:handle length:size windowBits:15] autorelease];
	}
	else if([method isEqual:@"-lh7-"])
	{
		handle=[[[XADLHAStaticHandle alloc] initWithHandle:handle length:size windowBits:16] autorelease];
	}
	else if([method isEqual:@"-lzs-"])
	{
		handle=[[[XADLArcLZSHandle alloc] initWithHandle:handle length:size] autorelease];
	}
	else if([method isEqual:@"-lz4-"])
	{
		// no compression, do nothing
	}
	else if([method isEqual:@"-lz5-"])
	{
		handle=[[[XADLArcLZ5Handle alloc] initWithHandle:handle length:size] autorelease];
	}
	else // not supported
	{
		return nil; 
	}

	if(checksum) handle=[XADCRCHandle IBMCRC16HandleWithHandle:handle length:size correctCRC:crc conditioned:NO];

	return handle;
}

-(NSString *)formatName { return @"LHA"; }

@end
