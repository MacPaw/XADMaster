#import "CSByteStreamHandle.h"
#import "XADPrefixTree.h"

@interface XADStuffItHuffmanHandle:CSByteStreamHandle
{
	XADPrefixTree *tree;
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length;
-(void)dealloc;

-(void)resetByteStream;
-(void)parseTree;
-(uint8_t)produceByteAtOffset:(off_t)pos;

@end
