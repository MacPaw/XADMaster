#import "XADCompressParser.h"
#import "XADCompressHandle.h"


@implementation XADCompressParser

+(int)requiredHeaderSize { return 3; }

+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name
{
	int length=[data length];
	const uint8_t *bytes=[data bytes];

	return length>=3&&bytes[0]==0x1f&&bytes[1]==0x9d;
}

-(void)parse
{
	CSHandle *fh=[self handle];

	[fh skipBytes:2];
	int flags=[fh readUInt8];

	[self addEntryWithDictionary:[NSDictionary dictionaryWithObjectsAndKeys:
		[self XADStringWithString:[[self name] stringByDeletingPathExtension]],XADFileNameKey,
// TODO: fix fileSize call
		[NSNumber numberWithLongLong:[[self handle] fileSize]-3],XADCompressedSizeKey,
		[self XADStringWithString:@"LZC"],XADCompressionNameKey,
		[NSNumber numberWithLongLong:3],XADDataOffsetKey,
		[NSNumber numberWithInt:flags],@"CompressFlags",
	nil]];
}

-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum
{
	return [[[XADCompressHandle alloc] initWithHandle:[self handleAtDataOffsetForDictionary:dict]
	flags:[[dict objectForKey:@"CompressFlags"] intValue]] autorelease];
}

-(NSString *)formatName { return @"Compress"; }

@end
