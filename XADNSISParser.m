#import "XADNSISParser.h"
#import "CSZlibHandle.h"
#import "CSBzip2Handle.h"
#import "XADLZMAHandle.h"
#import "XADCRCHandle.h"
#import "NSDateXAD.h"


static const uint8_t NSISSignature[16]={0xef,0xbe,0xad,0xde,0x4e,0x75,0x6c,0x6c,0x73,0x6f,0x66,0x74,0x49,0x6e,0x73,0x74};

@implementation XADNSISParser

+(int)requiredHeaderSize { return 0x10000; }

+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name
{
	const uint8_t *bytes=[data bytes];
	int length=[data length];

	for(int offs=0;offs<length+4+16;offs+=512)
	{
		if(memcmp(bytes+offs+4,NSISSignature,16)==0) return YES;
	}
	return NO;
}

-(void)parse
{
	CSHandle *fh=[self handle];

	[fh skipBytes:516];
	for(;;)
	{
		uint8_t buf[16];
		[fh readBytes:16 toBuffer:buf];
		if(memcmp(buf,NSISSignature,16)==0) break;
		[fh skipBytes:512-16];
	}

	uint32_t headerlength=[fh readUInt32LE];
	uint32_t archivelength=[fh readUInt32LE];
//	uint32_t compressedheaderlength=[fh readUInt32LE];

/*	if(compressedheaderlength==headerlength)
	{
		// uncomp
	}
	else if(islzma)
	{
	}
	else if(islzma+4)
	{
	}
	else if(compressedheaderlength&0x80000000)
	{
		// deflate
	}
	else
	{
		// solid deflate
	}*/

	int flag=[fh readUInt8];
	NSData *data=[fh readDataOfLength:5];
NSLog(@"%@",data);

	XADLZMAHandle *lh=[[[XADLZMAHandle alloc] initWithHandle:fh propertyData:data] autorelease];

	NSLog(@"NSIS %@",[lh readDataOfLength:256]);
}

-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum
{
	return nil;
}

-(NSString *)formatName { return @"NSIS"; }

@end
