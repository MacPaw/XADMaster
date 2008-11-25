#import "CSByteStreamHandle.h"

#define XADLZSSMatch -1
#define XADLZSSEnd -2

@interface XADLZSSHandle:CSByteStreamHandle
{
	int (*nextliteral_ptr)(id,SEL,int *,int *);
	uint8_t *windowbuffer;
	int windowmask,matchlength,matchoffset;
}

-(id)initWithHandle:(CSHandle *)handle windowSize:(int)windowsize;
-(id)initWithHandle:(CSHandle *)handle length:(off_t)length windowSize:(int)windowsize;
-(void)dealloc;

-(void)resetByteStream;
-(uint8_t)produceByteAtOffset:(off_t)pos;

-(void)resetLZSSHandle;
-(int)nextLiteralOrOffset:(int *)offset andLength:(int *)length;

@end
