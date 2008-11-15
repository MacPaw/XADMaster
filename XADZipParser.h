#import "XADArchiveParser.h"

@interface XADZipParser:XADArchiveParser
{
}

+(int)requiredHeaderSize;
+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name;

-(void)parse;
-(off_t)calculateOffsetForDisk:(int)disk offset:(off_t)offset;
-(void)findCentralDirectory;
//-(void)findNextZipMarkerStartingAt:(off_t)startpos;
//-(void)findNoSeekMarkerForDictionary:(NSMutableDictionary *)dict;
-(void)parseZipExtraWithDictionary:(NSMutableDictionary *)dict length:(int)length;

-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict;
-(CSHandle *)decompressionHandleWithHandle:(CSHandle *)parent method:(int)method size:(off_t)size;

-(NSString *)formatName;

@end
