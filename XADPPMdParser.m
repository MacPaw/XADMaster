#import "XADPPMdParser.h"
#import "XADPPMdVariantGHandle.h"
#import "XADPPMdVariantIHandle.h"
#import "NSDateXAD.h"

#import "XADCRCHandle.h"

@implementation XADPPMdParser

+(int)requiredHeaderSize { return 16; }

+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name;
{
	const uint8_t *bytes=[data bytes];
	int length=[data length];

	if(length<16) return NO;

	if(bytes[0]==0x84&&bytes[1]==0xac&&bytes[2]==0xaf&&bytes[3]==0x8f) return YES;
	if(bytes[3]==0x84&&bytes[2]==0xac&&bytes[1]==0xaf&&bytes[0]==0x8f) return YES;
	return NO;
}

-(void)parse
{
	CSHandle *fh=[self handle];

	uint32_t signature=[fh readID];

	BOOL bigendian;
	if(signature==0x84acaf8f) bigendian=YES;
	else bigendian=NO;

	uint32_t attrib;
	int info,namelen,time,date;

	if(bigendian)
	{
		attrib=[fh readUInt32BE];
		info=[fh readUInt16BE];
		namelen=[fh readUInt16BE];
		time=[fh readUInt16BE];
		date=[fh readUInt16BE];
	}
	else
	{
		attrib=[fh readUInt32LE];
		info=[fh readUInt16LE];
		namelen=[fh readUInt16LE];
		time=[fh readUInt16LE];
		date=[fh readUInt16LE];
	}

	int maxorder=(info&0x0f)+1;
	int suballocsize=((info>>4)&0xff)+1;
	int variant=(info>>12)+'A';

	NSData *filename=[fh readDataOfLength:namelen];

	NSMutableDictionary *dict=[NSMutableDictionary dictionaryWithObjectsAndKeys:
		[self XADStringWithData:filename],XADFileNameKey,
		[self XADStringWithString:[NSString stringWithFormat:@"PPMd Variant %c",variant]],XADCompressionNameKey,
		[NSNumber numberWithUnsignedLongLong:[fh offsetInFile]],XADDataOffsetKey,
		[NSNumber numberWithInt:maxorder],@"PPMdMaxOrder",
		[NSNumber numberWithInt:variant],@"PPMdVariant",
		[NSNumber numberWithInt:suballocsize],@"PPMdSubAllocSize",
	nil];

	if(date&0xc000) // assume that the next highest bit is always set in unix dates and never in DOS (true until 2011)
	{
		[dict setObject:[NSDate dateWithTimeIntervalSince1970:(date<<16)|time] forKey:XADLastModificationDateKey];
		[dict setObject:[NSNumber numberWithInt:attrib] forKey:XADPosixPermissionsKey];
	}
	else
	{
		[dict setObject:[NSDate XADDateWithMSDOSDateTime:(date<<16)|time] forKey:XADLastModificationDateKey];
		[dict setObject:[NSNumber numberWithInt:attrib] forKey:XADWindowsFileAttributesKey];
	}

	@try {
		off_t filesize=[fh fileSize];
		[dict setObject:[NSNumber numberWithUnsignedLongLong:filesize-16-namelen] forKey:XADCompressedSizeKey];
	} @catch(id e) { }

	[self addEntryWithDictionary:dict];
}

-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum
{
	CSHandle *handle=[self handleAtDataOffsetForDictionary:dict];

	int variant=[[dict objectForKey:@"PPMdVariant"] intValue];
	int maxorder=[[dict objectForKey:@"PPMdMaxOrder"] intValue];
	int suballocsize=[[dict objectForKey:@"PPMdSubAllocSize"] intValue];

	switch(variant)
	{
		case 'G':
			return [XADCRCHandle IEEECRC32HandleWithHandle:
			[[[XADPPMdVariantGHandle alloc] initWithHandle:handle maxOrder:maxorder subAllocSize:suballocsize<<20] autorelease]
			length:13745624 correctCRC:0xc1c1c00a conditioned:YES];

		default: return nil;
	}
}

-(NSString *)formatName { return @"PPMd"; }

@end
