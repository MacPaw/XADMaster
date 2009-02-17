#import "XADPackItParser.h"
#import "XADStuffItHuffmanHandle.h"
#import "XADCRCHandle.h"
#import "NSDateXAD.h"
#import "Paths.h"

@implementation XADPackItParser

+(int)requiredHeaderSize
{
	return 98;
}

+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name
{
	int length=[data length];
	const uint8_t *bytes=[data bytes];

	if(length<98) return NO;

	if(bytes[0]=='P'&&bytes[1]=='M'&&bytes[2]=='a')
	if(bytes[3]=='g'||(bytes[3]>='1'||bytes[3]<='6')) return YES;
//	if(XADCalculateCRC(0,bytes+4,92,XADCRCReverseTable_1021)==
//	XADUnReverseCRC16(CSUInt16BE(bytes+96))) return YES;

	return NO;
}

-(id)initWithHandle:(CSHandle *)handle name:(NSString *)name
{
	if(self=[super initWithHandle:handle name:name])
	{
		currdesc=nil;
		currhandle=nil;
	}
	return self;
}

-(void)dealloc
{
	[currdesc release];
	[currhandle release];
	[super dealloc];
}

-(void)parse
{
	CSHandle *handle=[self handle];

	for(;;)
	{
		uint32_t magic=[handle readID];
NSLog(@"%x",magic);
		if(magic=='PEnd') break;

		BOOL comp;
		CSHandle *fh;
		XADStuffItHuffmanHandle *hh=nil;

		if(magic=='PMag')
		{
			comp=NO;
			fh=handle;
		}
		else if(magic=='PMa4')
		{
			comp=YES;
			fh=hh=[[[XADStuffItHuffmanHandle alloc] initWithHandle:handle] autorelease];
		}
		else [XADException raiseIllegalDataException];

		int namelen=[fh readUInt8];
		if(namelen>63) namelen=63;
		uint8_t namebuf[63];
		[fh readBytes:63 toBuffer:namebuf];
		XADString *name=[self XADStringWithData:XADBuildMacPathWithBuffer(nil,namebuf,namelen)];

		uint32_t type=[fh readUInt32BE];
		uint32_t creator=[fh readUInt32BE];
		int finderflags=[fh readUInt16BE];
		[fh skipBytes:2];
		uint32_t datasize=[fh readUInt32BE];
		uint32_t rsrcsize=[fh readUInt32BE];
		uint32_t modification=[fh readUInt32BE];
		uint32_t creation=[fh readUInt32BE];
		/*int headcrc=*/[fh readUInt16BE];

		off_t start=[fh offsetInFile];

		NSMutableDictionary *datadesc;
		uint32_t datacompsize,rsrccompsize;
		off_t end;

		start=[fh offsetInFile];

		if(!comp)
		{
			[fh skipBytes:datasize+rsrcsize];
			int crc=[fh readUInt16BE];

			datacompsize=datasize;
			rsrccompsize=rsrcsize;
			end=start+datacompsize+rsrccompsize+2;

			datadesc=[NSMutableDictionary dictionaryWithObjectsAndKeys:
				[NSNumber numberWithLongLong:start],@"Offset",
				[NSNumber numberWithLongLong:datasize+rsrcsize],@"Length",
				[NSNumber numberWithInt:crc],@"CRC",
			nil];
		}
		else
		{
			[hh skipBytes:datasize];
			datacompsize=CSInputBufferOffset(hh->input);

			[hh skipBytes:rsrcsize];
			rsrccompsize=CSInputBufferOffset(hh->input)-datacompsize;

			int crc=[hh readUInt16BE];
			CSInputSkipToByteBoundary(hh->input);
			end=CSInputFileOffset(hh->input);

			datadesc=[NSMutableDictionary dictionaryWithObjectsAndKeys:
				[NSNumber numberWithLongLong:start],@"Offset",
				[NSNumber numberWithLongLong:end-start],@"Length",
				[NSNumber numberWithLongLong:datasize+rsrcsize],@"UncompressedLength",
				[NSNumber numberWithInt:crc],@"CRC",
			nil];
		}

		if(datasize||!rsrcsize)
		{
			[self addEntryWithDictionary:[NSMutableDictionary dictionaryWithObjectsAndKeys:
				name,XADFileNameKey,
				[NSNumber numberWithUnsignedInt:type],XADFileTypeKey,
				[NSNumber numberWithUnsignedInt:creator],XADFileCreatorKey,
				[NSNumber numberWithInt:finderflags],XADFinderFlagsKey,
				[NSNumber numberWithUnsignedInt:datasize],XADFileSizeKey,
				[NSNumber numberWithUnsignedInt:datacompsize],XADCompressedSizeKey,
				[NSDate XADDateWithTimeIntervalSince1904:modification],XADLastModificationDateKey,
				[NSDate XADDateWithTimeIntervalSince1904:creation],XADCreationDateKey,
				[self XADStringWithString:comp?@"Huffman":@"None"],XADCompressionNameKey,

				datadesc,@"PackItDataDescriptor",
				[NSNumber numberWithUnsignedInt:0],@"PackItDataOffset",
				[NSNumber numberWithUnsignedInt:datasize],@"PackItDataLength",
			nil]];
		}

		if(rsrcsize)
		{
			[self addEntryWithDictionary:[NSMutableDictionary dictionaryWithObjectsAndKeys:
				name,XADFileNameKey,
				[NSNumber numberWithUnsignedInt:type],XADFileTypeKey,
				[NSNumber numberWithUnsignedInt:creator],XADFileCreatorKey,
				[NSNumber numberWithInt:finderflags],XADFinderFlagsKey,
				[NSNumber numberWithUnsignedInt:rsrcsize],XADFileSizeKey,
				[NSNumber numberWithUnsignedInt:rsrccompsize],XADCompressedSizeKey,
				[NSDate XADDateWithTimeIntervalSince1904:modification],XADLastModificationDateKey,
				[NSDate XADDateWithTimeIntervalSince1904:creation],XADCreationDateKey,
				[self XADStringWithString:comp?@"Huffman":@"None"],XADCompressionNameKey,
				[NSNumber numberWithBool:YES],XADIsResourceForkKey,

				datadesc,@"PackItDataDescriptor",
				[NSNumber numberWithUnsignedInt:datasize],@"PackItDataOffset",
				[NSNumber numberWithUnsignedInt:rsrcsize],@"PackItDataLength",
			nil]];
		}

		[fh seekToFileOffset:end];
	}
}

-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum
{
	NSMutableDictionary *desc=[dict objectForKey:@"PackItDataDescriptor"];

	if(desc!=currdesc)
	{
		off_t offs=[[desc objectForKey:@"Offset"] longLongValue];
		off_t len=[[desc objectForKey:@"Length"] longLongValue];
		CSHandle *handle=[[self handle] nonCopiedSubHandleFrom:offs length:len];

		NSNumber *uncomplen=[desc objectForKey:@"UncompressedLength"];
		if(uncomplen) handle=[[[XADStuffItHuffmanHandle alloc] initWithHandle:handle length:[uncomplen longLongValue]] autorelease];

		handle=[XADCRCHandle CCITTCRC16HandleWithHandle:handle length:[handle fileSize]
		correctCRC:[[desc objectForKey:@"CRC"] intValue] conditioned:NO];

		[currdesc release];
		currdesc=[desc retain];
		[currhandle release];
		currhandle=[handle retain];
	}

	if(!currhandle) return nil;

	off_t offs=[[dict objectForKey:@"PackItDataOffset"] longLongValue];
	off_t len=[[dict objectForKey:@"PackItDataLength"] longLongValue];
	return [currhandle nonCopiedSubHandleFrom:offs length:len];
}

-(NSString *)formatName
{
	return @"PackIt";
}

@end
