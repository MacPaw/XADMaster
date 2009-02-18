#import "XADMacBinaryParser.h"

@implementation XADMacBinaryParser

+(int)requiredHeaderSize
{
	return 128;
}

+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name
{
	int length=[data length];
	const uint8_t *bytes=[data bytes];

	if(length<128) return NO;

	if(CSUInt32BE(bytes+102)=='mBIN') return YES; // MacBinary III

	if(bytes[0]!=0) return NO;
	if(bytes[74]!=0) return NO;
	if(XADCalculateCRC(0,bytes,124,XADCRCReverseTable_1021)==XADUnReverseCRC16(CSUInt16BE(bytes+124))) return YES; // MacBinary II

	if(bytes[82]!=0) return NO;
	for(int i=101;i<=125;i++) if(bytes[i]!=0) return NO;
	if(bytes[1]==0||bytes[1]>63) return NO;
	for(int i=0;i<bytes[1];i++) if(bytes[i+2]==0) return NO;
	if(CSUInt32BE(bytes+83)>0x7fffff) return NO;
	if(CSUInt32BE(bytes+87)>0x7fffff) return NO;

	return YES; // MacBinary I
}

-(void)parse
{
	[properties removeObjectForKey:XADDisableMacForkExpansionKey];
	[self addEntryWithDictionary:[NSMutableDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithBool:YES],XADIsMacBinaryKey,
	nil]];
}

-(CSHandle *)rawHandleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum
{
	return [self handle];
}

-(void)inspectEntryDictionary:(NSMutableDictionary *)dict
{
	NSNumber *rsrc=[dict objectForKey:XADIsResourceForkKey];
	if(rsrc&&[rsrc boolValue]) return;

	if([[self name] matchedByPattern:@"\\.sea(\\.|$)" options:REG_ICASE]||
	[[[dict objectForKey:XADFileNameKey] string] matchedByPattern:@"\\.(sea|sit|cpt)$" options:REG_ICASE])
	[dict setObject:[NSNumber numberWithBool:YES] forKey:XADIsArchiveKey];

	// TODO: Better detection of embedded archives. Also applies to BinHex!
//	if([[dict objectForKey:XADFileTypeKey] unsignedIntValue]=='APPL')...
}

-(NSString *)formatName
{
	return @"MacBinary";
}

@end
