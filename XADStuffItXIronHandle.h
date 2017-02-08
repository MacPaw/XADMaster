#import "CSBlockStreamHandle.h"

@interface XADStuffItXIronHandle:CSBlockStreamHandle
{
	uint8_t *block,*sorted;
	uint32_t *table;
	size_t currsize;

	int st4transform,fancymtf;

	unsigned int maxfreq1,maxfreq2,maxfreq3;
	unsigned int byteshift1,byteshift2,byteshift3;
	unsigned int countshift1,countshift2,countshift3;
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length;
-(void)dealloc;

-(void)resetBlockStream;
-(int)produceBlockAtOffset:(off_t)pos;

-(void)decodeBlockWithLength:(int)blocksize;

@end
