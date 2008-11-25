#import "CSInputBuffer.h"

extern NSString *XADInvalidPrefixCodeException;

@interface XADPrefixTree:NSObject
{
	int (*tree)[2];
	int numentries;
	BOOL isstatic;

	int currnode;
	NSMutableArray *stack;
}

+(XADPrefixTree *)prefixTree;

-(id)init;
-(id)initWithStaticTable:(int (*)[2])statictable;
-(void)dealloc;

-(void)addValue:(int)value forCodeWithHighBitFirst:(uint32_t)code length:(int)length;
-(void)addValue:(int)value forCodeWithHighBitFirst:(uint32_t)code length:(int)length repeatAt:(int)repeatpos;
-(void)addValue:(int)value forCodeWithLowBitFirst:(uint32_t)code length:(int)length;
-(void)addValue:(int)value forCodeWithLowBitFirst:(uint32_t)code length:(int)length repeatAt:(int)repeatpos;

-(void)startBuildingTree;
-(void)startZeroBranch;
-(void)startOneBranch;
-(void)finishBranches;
-(void)makeLeafWithValue:(int)value;
-(void)_pushNode;
-(void)_popNode;

@end

int CSInputNextSymbolFromTree(CSInputBuffer *buf,XADPrefixTree *tree);
int CSInputNextSymbolFromTreeLE(CSInputBuffer *buf,XADPrefixTree *tree);
