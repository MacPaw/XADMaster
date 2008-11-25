#import "XADArchiveParser.h"

// TODO: GzipSFX

@interface XADGzipParser:XADArchiveParser
{
}

+(int)requiredHeaderSize;
+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name;

//-(id)initWithHandle:(CSHandle *)handle;
//-(void)dealloc;

-(void)parse;

-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum;

-(NSString *)formatName;

@end
