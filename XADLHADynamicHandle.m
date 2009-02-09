#import "XADLHADynamicHandle.h"

@implementation XADLHADynamicHandle

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length
{
	if(self=[super initWithHandle:handle length:length windowSize:4096])
	{
		literalcode=;

		static const int lengths[64]=
		{
			3,4,4,4,5,5,5,5,5,5,5,5,6,6,6,6,
			6,6,6,6,6,6,6,6,7,7,7,7,7,7,7,7,
			7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,
			8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,
		};

		distancecode=[[XADPrefixCode alloc] initWithLengths:lengths numberOfSymbols:
		maximumLength:8 shortestCodeIsZeros:YES];
	}
	return self;
}

-(void)dealloc
{
	[literalcode release];
	[distancecode release];
	[super dealloc];
}

-(void)resetLZSSHandle
{
}

-(int)nextLiteralOrOffset:(int *)offset andLength:(int *)length atPosition:(off_t)pos
{
	int lit=CSInputNextSymbolUsingCode(input,literalcode);

	if(lit<0x100) return lit;
	else
	{
		*length=lit-0x100+3;

		int highbits=CSInputNextSymbolUsingCode(input,distancecode);
		int lowbits=CSInputNextBitString(input,6);
		*offset=(highbits<<6)+lowbits+1;

		return XADLZSSMatch;
	}
}

@end
