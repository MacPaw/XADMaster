#import "XADArchiveParser.h"

@interface XADOldNSISParser:XADArchiveParser
{
	off_t base;
	uint32_t stringtable;
}

+(int)requiredHeaderSize;
+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name;

-(void)parse;

-(void)parseOlderFormatWithHandle:(CSHandle *)fh;
-(void)parseOldFormatWithHandle:(CSHandle *)fh;

-(NSDictionary *)parseBlockOffsetsWithTotalSize:(uint32_t)totalsize;
-(NSDictionary *)parseStringsWithData:(NSData *)data;

-(XADPath *)cleanedPathForData:(NSData *)data;

-(CSHandle *)handleForBlockAtOffset:(off_t)offs;
-(CSHandle *)handleForBlockAtOffset:(off_t)offs length:(off_t)length;

-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum;
-(NSString *)formatName;

@end
