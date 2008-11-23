#import "CSByteStreamHandle.h"
#import "XADPrefixTree.h"

@interface XADZipImplodeHandle:CSByteStreamHandle
{
	uint8_t *dictionarywindow;
	int dictionarymask,offsetbits;

	int dictionarylen,dictionaryoffs;

	XADPrefixTree *literaltree,*lengthtree,*offsettree;
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length
largeDictionary:(BOOL)largedict literalTree:(BOOL)hasliterals;
-(void)dealloc;

-(XADPrefixTree *)parseImplodeTreeOfSize:(int)size handle:(CSHandle *)fh;

-(void)resetByteStream;
-(uint8_t)produceByteAtOffset:(off_t)pos;

@end
