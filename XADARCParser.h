#import "XADArchiveParser.h"
#import "CSByteStreamHandle.h"

@interface XADARCParser:XADArchiveParser
{
}

+(int)requiredHeaderSize;
+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name;

-(void)parse;
-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum;
-(NSString *)formatName;

@end


@interface XADARCSqueezeHandle:CSByteStreamHandle
{
	int nodes[257*2];
}

-(void)resetByteStream;
-(uint8_t)produceByteAtOffset:(off_t)pos;

@end

typedef struct XADARCCrunchEntry
{
	BOOL used;
	uint8_t byte;
	int next;
	int parent;
} XADARCCrunchEntry;

@interface XADARCCrunchHandle:CSByteStreamHandle
{
	BOOL fast;

	int numfreecodes,sp,lastcode;
	uint8_t lastbyte;

	XADARCCrunchEntry table[4096];
	uint8_t stack[4096];
}

-(id)initWithHandle:(CSHandle *)handle useFastHash:(BOOL)usefast;
-(id)initWithHandle:(CSHandle *)handle length:(off_t)length useFastHash:(BOOL)usefast;

-(void)resetByteStream;
-(uint8_t)produceByteAtOffset:(off_t)pos;
-(void)updateTableWithParent:(int)parent byteValue:(int)byte;

@end
