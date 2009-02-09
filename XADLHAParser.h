#import "XADArchiveParser.h"

@interface XADLHAParser:XADArchiveParser
{
}

+(int)requiredHeaderSize;
+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name;

-(void)parse;
-(void)parseExtendedForDictionary:(NSMutableDictionary *)dict size:(int)size;

-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum;
-(NSString *)formatName;

@end
