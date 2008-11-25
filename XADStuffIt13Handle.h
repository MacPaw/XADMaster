#import "XADLZSSHandle.h"
#import "XADPrefixTree.h"

@interface XADStuffIt13Handle:XADLZSSHandle
{
	XADPrefixTree *firsttree,*secondtree,*offsettree;
	XADPrefixTree *currtree;
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length;
-(void)dealloc;

-(void)resetLZSSHandle;
-(XADPrefixTree *)parseTreeOfSize:(int)numcodes metaTree:(XADPrefixTree *)metatree;
-(XADPrefixTree *)createTreeWithLengths:(const int *)lengths numberOfCodes:(int)numcodes;
-(int)nextLiteralOrOffset:(int *)offset andLength:(int *)length;

@end
