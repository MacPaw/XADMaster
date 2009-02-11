#import "XADArchiveParser.h"

// TODO later: Multivolume tar.

@interface XADTarParser:XADArchiveParser
{
	NSData *currentGlobalHeader;
}

+(int)requiredHeaderSize;
+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name;

-(void)parse;
-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum;
-(NSString *)formatName;

@end
