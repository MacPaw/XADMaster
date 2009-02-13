#import "XADArchiveParser.h"
#import "CSByteStreamHandle.h"

@interface XADDiskDoublerParser:XADArchiveParser
{
}

+(int)requiredHeaderSize;
+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name;

-(void)parse;
-(void)parseArchive;
-(void)parseArchive2;
-(void)parseFileHeaderWithHandle:(CSHandle *)fh name:(XADString *)name;

-(NSString *)nameForMethod:(int)method;

-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum;
-(NSString *)formatName;

@end


@interface XADDiskDoublerXORHandle:CSByteStreamHandle {}
-(uint8_t)produceByteAtOffset:(off_t)pos;
@end
