#import "XADNSISParser.h"
#import "CSZlibHandle.h"
#import "CSBzip2Handle.h"
#import "CSMemoryHandle.h"
#import "XADLZMAHandle.h"
#import "XADDeflateHandle.h"
#import "XAD7ZipBranchHandles.h"
#import "XADCRCHandle.h"
#import "NSDateXAD.h"

//#import "NSISOpcodes.h"



static BOOL IsNewSignature(const uint8_t *ptr)
{
	static const uint8_t NewSignature[16]={0xef,0xbe,0xad,0xde,0x4e,0x75,0x6c,0x6c,0x73,0x6f,0x66,0x74,0x49,0x6e,0x73,0x74};
	if(memcmp(ptr+4,NewSignature,16)!=0) return NO;
	if(CSUInt32LE(ptr)&2) return NO; // uninstaller
	return NO;
}

@implementation XADNSISParser

+(int)requiredHeaderSize { return 0x10000; }

+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name
{
	const uint8_t *bytes=[data bytes];
	int length=[data length];

	for(int offs=0;offs<length+4+16;offs+=512)
	{
		if(IsNewSignature(bytes+offs)) return YES;
	}
	return NO;
}

-(id)initWithHandle:(CSHandle *)handle name:(NSString *)name;
{
	if(self=[super initWithHandle:handle name:name])
	{
		solidhandle=nil;
	}
	return self;
}

-(void)dealloc
{
	[solidhandle release];
	[super dealloc];
}


-(void)parse
{
	CSHandle *fh=[self handle];

	[fh skipBytes:512];
	for(;;)
	{
		uint8_t buf[20];
		[fh readBytes:sizeof(buf) toBuffer:buf];
		[fh skipBytes:-(int)sizeof(buf)];

		if(IsNewSignature(buf)) { [self parseNewFormatWithHandle:fh]; return; }
		[fh skipBytes:512];
	}
}




static BOOL IsLZMA(uint8_t *sig) { return sig[0]==0x5d&&sig[1]==0x00&&sig[2]==0x00&&sig[5]==0x00; }

static CSHandle *AutodetectedHandleForSignature(CSHandle *handle,uint8_t *sig,off_t length)
{
	if(IsLZMA(sig))
	{
		[handle skipBytes:5];
		return [[[XADLZMAHandle alloc] initWithHandle:handle length:length
		propertyData:[NSData dataWithBytes:sig length:5]] autorelease];
	}
	else if(IsLZMA(sig+1))
	{
		[handle skipBytes:6];

		CSHandle *handle=[[[XADLZMAHandle alloc] initWithHandle:handle length:length
		propertyData:[NSData dataWithBytes:sig+1 length:5]] autorelease];

		switch(sig[0])
		{
			case 0: return handle;
			case 1: return [[[XAD7ZipBCJHandle alloc] initWithHandle:handle length:length] autorelease];
			default: [XADException raiseNotSupportedException]; return nil;
		}
	}
	else if(sig[0]==0x78&&sig[1]==0xda)
	{
		[handle skipBytes:2];
NSLog(@"what");
		return [CSZlibHandle deflateHandleWithHandle:handle length:length];
	}
	else
	{
//		fh=[[[XADDeflateHandle alloc] initWithHandle:fh length:headerlength variant:XADNSISDeflateVariant] autorelease];
NSLog(@"what2");
		return [CSZlibHandle deflateHandleWithHandle:handle length:length];
	}
}


-(void)parseNewFormatWithHandle:(CSHandle *)fh
{
	[fh skipBytes:20];

	uint32_t headerlength=[fh readUInt32LE];
	uint32_t archivelength=[fh readUInt32LE];

	uint8_t sig[11];
	[fh readBytes:sizeof(sig) toBuffer:sig];

	uint32_t compressedheaderfield=CSUInt32LE(sig);
	uint32_t compressedheaderlength=compressedheaderfield&0x7fffffff;
	BOOL headercompressedflag=compressedheaderfield&0x80000000?YES:NO;

	NSData *headerdata;
	if(compressedheaderfield==headerlength)
	{
		// Uncompressed header
		[fh skipBytes:-7];
		headerdata=[fh readDataOfLength:headerlength];
	}
	else if(headercompressedflag&&compressedheaderlength<headerlength&&compressedheaderlength>32)
	{
		[fh skipBytes:-7];
		CSHandle *handle=AutodetectedHandleForSignature(fh,sig+4,headerlength);
		headerdata=[handle readDataOfLength:headerlength];
	}
	else
	{
		[fh skipBytes:-11];
		solidhandle=[AutodetectedHandleForSignature(fh,sig,CSHandleMaxLength) retain];
		if([solidhandle readInt32LE]!=headerlength) [XADException raiseIllegalDataException];
		headerdata=[solidhandle readDataOfLength:headerlength];
	}

	[self parseSectionsWithHandle:[CSMemoryHandle memoryHandleForReadingData:headerdata]];
}

-(void)parseSectionsWithHandle:(CSHandle *)fh
{
	flags=[fh readUInt32LE];

	pages.offset=[fh readUInt32LE];
	pages.num=[fh readUInt32LE];
	sections.offset=[fh readUInt32LE];
	sections.num=[fh readUInt32LE];
	entries.offset=[fh readUInt32LE];
	entries.num=[fh readUInt32LE];
	strings.offset=[fh readUInt32LE];
	strings.num=[fh readUInt32LE];
	langtables.offset=[fh readUInt32LE];
	langtables.num=[fh readUInt32LE];
	ctlcolours.offset=[fh readUInt32LE];
	ctlcolours.num=[fh readUInt32LE];
	// font?
	data.offset=[fh readUInt32LE];
	data.num=[fh readUInt32LE];

	[fh seekToFileOffset:entries.offset];
	[self parseEntriesWithHandle:fh];
}

-(void)parseEntriesWithHandle:(CSHandle *)fh
{
	for(int i=0;i<entries.num;i++)
	{
		int type=[fh readUInt32LE];
		uint32_t args[6];
		for(int i=0;i<sizeof(args)/sizeof(args[0]);i++) args[i]=[fh readUInt32LE];

		NSLog(@"%d: %d %d %d %d %d %d",type,args[0],args[1],args[2],args[3],args[4],args[5]);
	}
}

-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum
{
	return nil;
}

-(NSString *)formatName { return @"NSIS"; }

@end
