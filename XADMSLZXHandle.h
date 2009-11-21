#import "XADLZSSHandle.h"
#import "XADPrefixCode.h"

@interface XADMSLZXHandle:XADLZSSHandle
{
	XADPrefixCode *maincode,*lengthcode,*offsetcode;

	int numslots;
	BOOL ispreprocessed;
	uint32_t preprocessoffset;

	int blocktype,blocksize;
	int r0,r1,r2;
	int mainlengths[256+50*8],lengthlengths[249];
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length windowBits:(int)windowbits;
-(void)dealloc;

-(void)resetLZSSHandle;
-(int)nextLiteralOrOffset:(int *)offset andLength:(int *)length atPosition:(off_t)pos;

-(void)readBlockHeader;
-(void)readDeltaLengths:(int *)lengths count:(int)count alternateMode:(BOOL)altmode;

@end
