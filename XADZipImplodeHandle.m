#import "XADZipImplodeHandle.h"
#import "XADException.h"

@implementation XADZipImplodeHandle

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length
largeDictionary:(BOOL)largedict hasLiterals:(BOOL)hasliterals
{
	if(self=[super initWithHandle:handle length:length windowSize:largedict?8192:4096])
	{
		if(largedict) offsetbits=7;
		else offsetbits=6;

		literals=hasliterals;

		literalcode=lengthcode=offsetcode=nil;
	}
	return self;
}

-(void)dealloc
{
	[literalcode release];
	[lengthcode release];
	[offsetcode release];
	[super dealloc];
}

-(void)resetLZSSHandle
{
	[literalcode release];
	[lengthcode release];
	[offsetcode release];
	literalcode=lengthcode=offsetcode=nil;

	if(literals) literalcode=[self allocAndParseCodeOfSize:256];
	lengthcode=[self allocAndParseCodeOfSize:64];
	offsetcode=[self allocAndParseCodeOfSize:64];
}

-(XADPrefixCode *)allocAndParseCodeOfSize:(int)size
{
	int numgroups=CSInputNextByte(input)+1;

	int codelengths[size],currcode=0;
	for(int i=0;i<numgroups;i++)
	{
		int val=CSInputNextByte(input);
		int num=(val>>4)+1;
		int length=(val&0x0f)+1;
		while(num--) codelengths[currcode++]=length;
	}

	return [[XADPrefixCode alloc] initWithLengths:codelengths numberOfSymbols:size maximumLength:16 shortestCodeIsZeros:NO];

/*	int codelength[numgroups];
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

	XADPrefixTree *code=[XADPrefixTree prefixTree];

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
			[code addValue:start+j forCodeWithHighBitFirst:code>>16-length length:length];
			code+=1<<16-length;
		}
	}

	return code;*/

}

-(int)nextLiteralOrOffset:(int *)offset andLength:(int *)length
{
	if(CSInputNextBitLE(input))
	{
		if(literalcode) return CSInputNextSymbolUsingCodeLE(input,literalcode);
		else return CSInputNextBitStringLE(input,8);
	}
	else
	{
		*offset=CSInputNextBitStringLE(input,offsetbits);
		*offset|=CSInputNextSymbolUsingCodeLE(input,offsetcode)<<offsetbits;
		*offset+=1;

		*length=CSInputNextSymbolUsingCodeLE(input,lengthcode)+2;
		if(*length==65) *length+=CSInputNextBitStringLE(input,8);
		if(literals) *length++;

		return XADLZSSMatch;
	}
}

@end
