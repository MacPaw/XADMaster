#import "XADArchiveParser.h"
#import "XADRARHandle.h"

typedef struct RARBlock
{
	int crc,type,flags;
	int headersize;
	off_t datasize;
	off_t start;
	CSHandle *fh;
} RARBlock;

@interface XADRARParser:XADArchiveParser
{
	int archiveflags,encryptversion;

	NSMutableDictionary *lastcompressed;
}

+(int)requiredHeaderSize;
+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name;
+(XADRegex *)volumeRegexForFilename:(NSString *)filename;
+(BOOL)isFirstVolume:(NSString *)filename;

-(void)parse;
-(RARBlock)readArchiveHeader;
-(RARBlock)readFileHeaderWithBlock:(RARBlock)block;
-(RARBlock)findNextFileHeaderAfterBlock:(RARBlock)block;
-(void)readCommentBlock:(RARBlock)block;
-(XADString *)parseNameData:(NSData *)data flags:(int)flags;

-(RARBlock)readBlockHeader;
-(void)skipBlock:(RARBlock)block;

-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum;
-(CSHandle *)handleForSolidStreamWithObject:(id)obj wantChecksum:(BOOL)checksum;
-(NSString *)formatName;

@end


@interface XADEmbeddedRARParser:XADRARParser
{
}

+(int)requiredHeaderSize;
+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name;

-(void)parse;
-(NSString *)formatName;

@end
