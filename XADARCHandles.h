#import "CSByteStreamHandle.h"
#import "LZW.h"

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

@interface XADARCCrushHandle:CSByteStreamHandle
{
	LZW *lzw;
	int symbolsize;

	int currbyte;
	uint8_t buffer[8192];
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length;
-(void)dealloc;

-(void)resetByteStream;
-(uint8_t)produceByteAtOffset:(off_t)pos;

@end

