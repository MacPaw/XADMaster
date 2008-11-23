#import "XADArchiveParser.h"

@interface XADStuffItParser:XADArchiveParser
{
}

-(void)parse;
-(NSData *)pathNameDataWithParentDictionary:(NSMutableDictionary *)parent bytes:(const char *)bytes length:(int)length;
-(XADString *)nameOfCompressionMethod:(int)method;

-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum;
-(NSString *)formatName;

@end

