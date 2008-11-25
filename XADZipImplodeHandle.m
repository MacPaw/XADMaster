#import "XADZipImplodeHandle.h"
#import "XADException.h"

@implementation XADZipImplodeHandle

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length
largeDictionary:(BOOL)largedict literalTree:(BOOL)hasliterals
{
	if(self=[super initWithHandle:handle length:length windowSize:largedict?8192:4096])
	{
		if(largedict) offsetbits=7;
		else offsetbits=6;

		literals=hasliterals;

		literaltree=lengthtree=offsettree=nil;
	}
	return self;
}

-(void)dealloc
{
	[literaltree release];
	[lengthtree release];
	[offsettree release];
	[super dealloc];
}

-(void)resetLZSSHandle
{
	[literaltree release];
	[lengthtree release];
	[offsettree release];
	literaltree=lengthtree=offsettree=nil;

	if(literals) literaltree=[[self parseTreeOfSize:256] retain];
	lengthtree=[[self parseTreeOfSize:64] retain];
	offsettree=[[self parseTreeOfSize:64] retain];
}

-(XADPrefixTree *)parseTreeOfSize:(int)size
{
	int numgroups=CSInputNextByte(input)+1;

	int codelength[numgroups];
	int numcodes[numgroups];
	int valuestart[numgroups];
	int totalcodes=0;

	for(int i=0;i<numgroups;i++)
	{
		int val=CSInputNextByte(input);

		codelength[i]=(val&0x0f)+1;
		numcodes[i]=(val>>4)+1;
		valuestart[i]=totalcodes;
		totalcodes+=numcodes[i];
	}

	if(totalcodes!=size) [XADException raiseIllegalDataException];

	XADPrefixTree *tree=[XADPrefixTree prefixTree];

	int code=0;
	for(int length=16;length>=1;length--)
	for(int n=numgroups-1;n>=0;n--)
	{
		if(codelength[n]!=length) continue;

		int num=numcodes[n];
		int start=valuestart[n];

		for(int j=num-1;j>=0;j--)
		{
			// Instead of reversing to get a low-bit-first code, we shift and use high-bit-first.
			[tree addValue:start+j forCodeWithHighBitFirst:code>>16-length length:length];
			code+=1<<16-length;
		}
	}

	return tree;
}

-(int)nextLiteralOrOffset:(int *)offset andLength:(int *)length
{
	if(CSInputNextBitLE(input))
	{
		if(literaltree) return CSInputNextSymbolFromTreeLE(input,literaltree);
		else return CSInputNextBitStringLE(input,8);
	}
	else
	{
		*offset=CSInputNextBitStringLE(input,offsetbits);
		*offset|=CSInputNextSymbolFromTreeLE(input,offsettree)<<offsetbits;
		*offset+=1;

		*length=CSInputNextSymbolFromTreeLE(input,lengthtree)+2;
		if(*length==65) *length+=CSInputNextBitStringLE(input,8);
		if(literals) *length++;

		return XADLZSSMatch;
	}
}

@end
