#import "XADArchiveParser.h"
#import "CSByteStreamHandle.h"
#import "LZW.h"

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
	BOOL blockmode;

	LZW *lzw;
	int symbolsize,symbolcounter;

	uint8_t *buffer;
	int bufsize,currbyte;

}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length;

-(void)resetByteStream;
-(uint8_t)produceByteAtOffset:(off_t)pos;

@end
