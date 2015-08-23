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
}

+(int)requiredHeaderSize;
+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name;
+(NSArray *)volumesForHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name;

-(void)setPassword:(NSString *)newpassword;

-(void)parse;

-(NSMutableDictionary *)readFileBlockHeader:(RAR5Block)block;
-(RAR5Block)readBlockHeader;
-(void)skipBlock:(RAR5Block)block;
-(off_t)endOfBlockHeader:(RAR5Block)block;
-(NSData *)encryptionKeyForPassword:(NSString *)passwordstring salt:(NSData *)salt strength:(int)strength passwordCheck:(NSData *)check;

-(NSString *)formatName;

@end

@interface XADEmbeddedRAR5Parser:XADRAR5Parser
{
}

-(NSString *)formatName;

@end

