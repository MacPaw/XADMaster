#import "XADArchiveParser.h"

@interface XAD7ZipParser:XADArchiveParser
{
}

+(int)requiredHeaderSize;
+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name;
+(XADRegex *)volumeRegexForFilename:(NSString *)filename;
+(BOOL)isFirstVolume:(NSString *)filename;

-(void)parse;

-(NSDictionary *)parseStreamsInfoForHandle:(CSHandle *)handle;
-(NSArray *)parsePackInfoForHandle:(CSHandle *)handle;
-(NSArray *)parseCodersInfoForHandle:(CSHandle *)handle;
-(void)parseFolderForHandle:(CSHandle *)handle dictionary:(NSMutableDictionary *)dictionary;
-(NSArray *)parseSubStreamsInfoForHandle:(CSHandle *)handle folders:(NSArray *)folders;

-(NSIndexSet *)parseBoolVector:(CSHandle *)handle numberOfElements:(int)num;
-(void)parseCRCsForHandle:(CSHandle *)handle array:(NSMutableArray *)array;

-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum;
-(NSString *)formatName;

@end
