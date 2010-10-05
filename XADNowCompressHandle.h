#import "CSBlockStreamHandle.h"

@interface XADNowCompressHandle:CSBlockStreamHandle
{
	CSHandle *parent;
	off_t startoffset;

	int numblocks,nextblock;
	struct
	{
		uint32_t offs;
		int flags,padding;
	} *blocks;

	uint8_t inblock[0x8000],outblock[0x8000];
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length;

-(void)resetBlockStream;
-(int)produceBlockAtOffset:(off_t)pos;

@end
