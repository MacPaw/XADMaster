#import "XADArchiveParser.h"

@interface XADOldNSISParser:XADArchiveParser
{
	off_t base;
	uint32_t stringtable;
}

+(int)requiredHeaderSize;
+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name;

-(void)parse;

-(void)parseOlderFormat;
-(void)parseOldFormat;
-(void)parseWithHeaderCompressedLength:(uint32_t)complength uncompressedLength:(uint32_t)uncomplength
totalDataLength:(uint32_t)datalength;
-(void)parseWithHeaderLength:(uint32_t)headerlength offset:(uint32_t)headeroffset
totalDataLength:(uint32_t)datalength;
-(void)parseWithHeader:(NSData *)header blocks:(NSDictionary *)blocks strings:(NSDictionary *)strings;

-(NSDictionary *)parseBlockOffsetsWithTotalSize:(uint32_t)totalsize;
-(NSDictionary *)parseStringsWithData:(NSData *)data maxOffsets:(int)maxnumoffsets;

-(XADPath *)cleanedPathForData:(NSData *)data;

-(CSHandle *)handleForBlockAtOffset:(off_t)offs;
-(CSHandle *)handleForBlockAtOffset:(off_t)offs length:(off_t)length;

-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum;
-(NSString *)formatName;

@end
