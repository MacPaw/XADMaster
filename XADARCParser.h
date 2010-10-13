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

typedef struct ARCCrunchEntry
{
	BOOL used;
	uint8_t byte;
	int next;
	int parent;
};

#define ARCTABSIZE      4096
#define ARCNO_PRED      0xFFFF

struct ArcCrunchData {
  struct xadInOut *io;
  struct ArcCrunchEntry string_tab[ARCTABSIZE];
  xadUINT8 newhash;
  xadUINT8 stack[ARCTABSIZE];
};

  struct ArcCrunchData *ad;
  xadUINT8 finchar;
  struct ArcCrunchEntry *ep;   /* allows faster table handling */
  xadUINT16 code, newcode, oldcode, numfreecodes, sp;

@interface XADARCCrushHandle:CSByteStreamHandle
{
	BOOL fast;
}

-(void)initWithHandle:(CSHandle *)handle useFastHash:(BOOL)usefast;
-(void)initWithHandle:(CSHandle *)handle length:(off_t)length useFastHash:(BOOL)usefast;

-(void)resetByteStream;
-(uint8_t)produceByteAtOffset:(off_t)pos;

@end
