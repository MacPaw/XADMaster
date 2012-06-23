#import "XADArchiveParser.h"
#import "PDF/PDFParser.h"

@interface XADPDFParser:XADArchiveParser
{
}

-(id)initWithHandle:(CSHandle *)handle name:(NSString *)name;
-(void)dealloc;

+(int)requiredHeaderSize;
+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name;

-(void)parse;
-(NSString *)compressionNameForStream:(PDFStream *)stream excludingLast:(BOOL)excludelast;

-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum;

-(NSString *)formatName;

@end
