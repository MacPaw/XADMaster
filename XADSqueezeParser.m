#import "XADSqueezeParser.h"
#import "XADSqueezeHandle.h"
#import "XADRLE90Handle.h"
#import "XADChecksumHandle.h"
#import "NSDateXAD.h"

@implementation XADSqueezeParser

+(int)requiredHeaderSize { return 5; }

+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name
{
	const uint8_t *bytes=[data bytes];
	int length=[data length];

	if(length<5) return NO;

	if(bytes[0]!=0x76||bytes[1]!=0xff) return NO;

	if(bytes[4]==0) return NO;
	for(int i=4;i<length;i++)
	{
		if(bytes[i]==0) break;
		if(bytes[i]<32) return NO;
	}

	return YES;
}

-(void)parse
{
	CSHandle *fh=[self handle];

	[fh skipBytes:2];

	int sum=[fh readUInt16LE];

	NSMutableData *data=[NSMutableData data];
	uint8_t byte;
	while((byte=[fh readUInt8])) [data appendBytes:&byte length:1];

	off_t dataoffset=[fh offsetInFile];

	NSMutableDictionary *dict=[NSMutableDictionary dictionaryWithObjectsAndKeys:
		[self XADPathWithData:data separators:XADNoPathSeparator],XADFileNameKey,
		[self XADStringWithString:@"Squeeze"],XADCompressionNameKey,
		[NSNumber numberWithUnsignedLongLong:dataoffset],XADDataOffsetKey,
		[NSNumber numberWithInt:sum],@"SqueezeChecksum",
	nil];

	[fh seekToEndOfFile];
	off_t endoffile=[fh offsetInFile];
	[fh skipBytes:-8];

	int marker=[fh readUInt16LE];
	if(marker==0xff77)
	{
		int date=[fh readUInt16LE];
		int time=[fh readUInt16LE];
		[dict setObject:[NSDate XADDateWithMSDOSDate:date time:time] forKey:XADLastModificationDateKey];

		NSNumber *compsize=[NSNumber numberWithLongLong:endoffile-dataoffset-8];
		[dict setObject:compsize forKey:XADCompressedSizeKey];
		[dict setObject:compsize forKey:XADDataLengthKey];
	}
	else
	{
		NSNumber *compsize=[NSNumber numberWithLongLong:endoffile-dataoffset];
		[dict setObject:compsize forKey:XADCompressedSizeKey];
		[dict setObject:compsize forKey:XADDataLengthKey];
	}

	const uint8_t *bytes=[data bytes];
	int length=[data length];
	if(length>4)
	if(bytes[length-4]=='.')
	if(tolower(bytes[length-3])=='l')
	if(tolower(bytes[length-2])=='b')
	if(tolower(bytes[length-1])=='r')
	{
		[dict setObject:[NSNumber numberWithBool:YES] forKey:XADIsArchiveKey];
	}

	[self addEntryWithDictionary:dict];
}

-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum
{
	CSHandle *handle=[self handleAtDataOffsetForDictionary:dict];
	int sum=[[dict objectForKey:@"SqueezeChecksum"] intValue];

	handle=[[[XADSqueezeHandle alloc] initWithHandle:handle] autorelease];
	handle=[[[XADRLE90Handle alloc] initWithHandle:handle] autorelease];

	if(checksum) handle=[[[XADChecksumHandle alloc] initWithHandle:handle
	length:CSHandleMaxLength correctChecksum:sum mask:0xffff] autorelease];

	return handle;
}

-(NSString *)formatName { return @"Squeeze"; }

@end




