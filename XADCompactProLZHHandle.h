#import "XADLZSSHandle.h"
#import "XADPrefixTree.h"

@interface XADCompactProLZHHandle:XADLZSSHandle
{
	XADPrefixTree *literaltree,*lengthtree,*offsettree;
	int blocksize,blockcount;
	off_t blockstart;
}

-(id)initWithHandle:(CSHandle *)handle blockSize:(int)blocklen;
-(void)dealloc;

-(void)resetLZSSHandle;
-(XADPrefixTree *)parseTreeOfSize:(int)size;
-(int)nextLiteralOrOffset:(int *)offset andLength:(int *)length;

@end
