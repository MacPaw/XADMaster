#import "XADArchiveParser.h"

typedef struct RAR5Block
{
	uint32_t crc;
	uint64_t headersize,type,flags;
	uint64_t extrasize,datasize;
	off_t start,outerstart;
	CSHandle *fh;
} RAR5Block;

@interface XADRAR5Parser:XADArchiveParser
{
	NSData *headerkey;
	NSMutableDictionary *cryptocache;

	NSMutableArray *solidstreams,*currsolidstream;
	off_t totalsolidsize;
}

+(int)requiredHeaderSize;
+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name;
+(NSArray *)volumesForHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name;

-(void)parse;
-(void)addEntryWithDictionary:(NSMutableDictionary *)dict
inputParts:(NSArray *)parts isCorrupted:(BOOL)iscorrupted;

-(NSMutableDictionary *)readFileBlockHeader:(RAR5Block)block;
-(RAR5Block)readBlockHeader;
-(void)skipBlock:(RAR5Block)block;
-(off_t)endOfBlockHeader:(RAR5Block)block;
-(NSData *)encryptionKeyForPassword:(NSString *)passwordstring salt:(NSData *)salt strength:(int)strength passwordCheck:(NSData *)check;
-(NSData *)hashKeyForPassword:(NSString *)passwordstring salt:(NSData *)salt strength:(int)strength passwordCheck:(NSData *)check;
-(NSDictionary *)keysForPassword:(NSString *)passwordstring salt:(NSData *)salt strength:(int)strength passwordCheck:(NSData *)check;

-(CSInputBuffer *)inputBufferWithDictionary:(NSDictionary *)dict;
-(CSHandle *)inputHandleWithDictionary:(NSDictionary *)dict;

-(NSString *)formatName;

@end

@interface XADEmbeddedRAR5Parser:XADRAR5Parser
{
}

-(NSString *)formatName;

@end

