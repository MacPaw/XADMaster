#import "XADArchiveParser.h"

@interface XADNowCompressParser:XADArchiveParser
{
	int totalentries,currentries;
	NSMutableArray *entries;
}

+(int)requiredHeaderSize;
+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name;

-(void)parse;
-(void)parseDirectoryWithParent:(XADPath *)parent numberOfEntries:(int)numentries;

-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum;
-(NSString *)formatName;

@end
