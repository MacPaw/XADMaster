#import "XADStuffItXParser.h"
#import "XADStuffItXBlockHandle.h"
//#import "XADStuffItXBrimstoneHandle.h"
#import "XADStuffItXCyanideHandle.h"
//#import "XADStuffItXDarkhorseHandle.h"
#import "XADCRCHandle.h"

@implementation XADStuffItXParser

+(int)requiredHeaderSize { return 10; }

+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name;
{
	const uint8_t *bytes=[data bytes];
	int length=[data length];

	if(length<8) return NO;

	return bytes[0]=='S'&&bytes[1]=='t'&&bytes[2]=='u'&&bytes[3]=='f'&&bytes[4]=='f'
	&&bytes[5]=='I'&&bytes[6]=='t'&&(bytes[7]=='!'||bytes[7]=='?');
}

-(void)parse
{
	NSMutableDictionary *dict=[NSMutableDictionary dictionaryWithObjectsAndKeys:
		[self XADStringWithString:@"Test"],XADFileNameKey,
		[self XADStringWithString:@"Cyanide"],XADCompressionNameKey,
		[NSNumber numberWithUnsignedInt:0xc0288c62],@"StuffItXCRC32",
	nil];

	[self addEntryWithDictionary:dict];
}

-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum
{
	CSHandle *handle=[self handle];
	[handle seekToFileOffset:133];

	handle=[[[XADStuffItXBlockHandle alloc] initWithHandle:handle] autorelease];

	handle=[[[XADStuffItXCyanideHandle alloc] initWithHandle:handle] autorelease];

	if(checksum) handle=[XADCRCHandle IEEECRC32HandleWithHandle:handle length:387633
	correctCRC:[[dict objectForKey:@"StuffItXCRC32"] unsignedIntValue] conditioned:YES];

	return handle;
}

-(NSString *)formatName { return @"StuffIt X"; }

@end
