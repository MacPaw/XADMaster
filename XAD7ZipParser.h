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
-(NSArray *)parsePackedStreamsForHandle:(CSHandle *)handle;
-(NSArray *)parseFoldersForHandle:(CSHandle *)handle packedStreams:(NSArray *)packedstreams;
-(void)parseFolderForHandle:(CSHandle *)handle dictionary:(NSMutableDictionary *)dictionary packedStreams:(NSArray *)packedstreams;
-(NSArray *)parseSubStreamsInfoForHandle:(CSHandle *)handle folders:(NSArray *)folders;

-(NSIndexSet *)parseBoolVector:(CSHandle *)handle numberOfElements:(int)num;
-(void)parseCRCsForHandle:(CSHandle *)handle array:(NSMutableArray *)array;

-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum;
-(CSHandle *)handleForFolder:(NSDictionary *)folder substreamIndex:(int)substream;
-(CSHandle *)outHandleForFolder:(NSDictionary *)folder index:(int)index;
-(CSHandle *)inHandleForFolder:(NSDictionary *)folder coder:(NSDictionary *)coder index:(int)index;
-(CSHandle *)inHandleForFolder:(NSDictionary *)folder index:(int)index;

-(NSString *)formatName;

@end
