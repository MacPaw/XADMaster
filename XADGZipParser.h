#import "XADArchiveParser.h"

// TODO: GZipSFX

@interface XADGZipParser:XADArchiveParser
{
	off_t datapos;
}

+(int)requiredHeaderSize;
+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name;

//-(id)initWithHandle:(CSHandle *)handle;
//-(void)dealloc;

-(void)parse;

-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict;

-(NSString *)formatName;

@end
