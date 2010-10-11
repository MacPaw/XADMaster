#import "XADArchiveParser.h"
#import "CSByteStreamHandle.h"

@interface XADZooParser:XADArchiveParser
{
}

+(int)requiredHeaderSize;
+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name;

-(void)parse;
-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum;
-(NSString *)formatName;

@end

@interface XADZooMethod1Handle:CSByteStreamHandle
{
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length;

@end
