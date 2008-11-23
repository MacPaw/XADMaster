#import "XADStuffItHuffmanHandle.h"

@implementation XADStuffItHuffmanHandle

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length
{
	if(self=[super initWithHandle:handle length:length])
	{
		tree=nil;
	}
	return self;
}

-(void)dealloc
{
	[tree release];
	[super dealloc];
}

-(void)resetByteStream
{
	[tree release];
	tree=[XADPrefixTree new];

	[tree startBuildingTree];
	[self parseTree];
}

-(void)parseTree
{
	if(CSInputNextBit(input)==1)
	{
		[tree makeLeafWithValue:CSInputNextBitString(input,8)];
	}
	else
	{
		[tree startZeroBranch];
		[self parseTree];
		[tree startOneBranch];
		[self parseTree];
		[tree finishBranches];
	}
}

-(uint8_t)produceByteAtOffset:(off_t)pos
{
	return CSInputNextSymbolFromTree(input,tree);
}

@end
