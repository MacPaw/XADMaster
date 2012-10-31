#import "XADArchiveParser.h"
#import "CSBlockStreamHandle.h"

@interface XADStuffItParser:XADArchiveParser
{
}

-(void)parse;
-(XADString *)nameOfCompressionMethod:(int)method;

-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum;
-(NSData *)keyForEntryWithDictionary:(NSDictionary *)dict;
-(CSHandle *)decryptHandleForEntryWithDictionary:(NSDictionary *)dict handle:(CSHandle *)fh;
-(NSString *)formatName;

@end
