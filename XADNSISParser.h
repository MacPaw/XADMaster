#import "XADArchiveParser.h"

@interface XADNSISParser:XADArchiveParser
{
	CSHandle *solidhandle;

	uint32_t flags;
	struct { uint32_t offset,num; } pages,sections,entries,strings,langtables,ctlcolours,data;
}

+(int)requiredHeaderSize;
+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name;

-(void)parse;

-(void)parseNewFormatWithHandle:(CSHandle *)fh;
-(void)parseSectionsWithHandle:(CSHandle *)fh;
-(void)parseEntriesWithHandle:(CSHandle *)fh;

-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum;
-(NSString *)formatName;

@end
