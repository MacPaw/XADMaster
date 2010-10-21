#import "XADARCDistillHandle.h"
#import "XADException.h"

static const int offsetlengths[0x40]=
{
	3,4,4,4, 5,5,5,5, 5,5,5,5, 6,6,6,6, 6,6,6,6, 6,6,6,6, 7,7,7,7, 7,7,7,7,
	7,7,7,7, 7,7,7,7, 7,7,7,7, 7,7,7,7, 8,8,8,8, 8,8,8,8, 8,8,8,8, 8,8,8,8,
};

@implementation XADARCDistillHandle

-(id)initWithHandle:(CSHandle *)handle
{
	return [self initWithHandle:handle length:CSHandleMaxLength];
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length
{
	if(self=[super initWithHandle:handle length:length windowSize:2048])
	{
		offsetcode=[[XADPrefixCode alloc] initWithLengths:offsetlengths numberOfSymbols:0x40
		maximumLength:8 shortestCodeIsZeros:YES];
	}
	return self;
}

-(void)dealloc
{
	[offsetcode release];
	[super dealloc];
}

-(void)resetLZSSHandle
{
	numnodes=CSInputNextUInt16LE(input);
	int codelength=CSInputNextByte(input);

	if(numnodes>0x275) [XADException raiseDecrunchException];

	for(int i=0;i<numnodes;i++)
	nodes[i]=CSInputNextBitStringLE(input,codelength);

//	CSInputSkipToByteBoundary(input);
}

-(void)expandFromPosition:(off_t)pos
{
	while(XADLZSSShouldKeepExpanding(self))
	{
		int symbol=numnodes-2;
		for(;;)
		{
			int bit=CSInputNextBitLE(input);
			symbol=nodes[symbol+bit];
			if(symbol>=numnodes) break;
		}
		symbol-=numnodes;

//NSLog(@"%x",symbol);

		if(symbol<256)
		{
			XADEmitLZSSLiteral(self,symbol,&pos);
		}
		else if(symbol==256)
		{
			[self endLZSSHandle];
			return;
		}
		else
		{
			int length=symbol-0x101+3;

			int offsetsymbol=CSInputNextSymbolUsingCodeLE(input,offsetcode);

			int extralength;
			if(pos>=0x1000-0x3c) extralength=7;
			else if(pos>=0x800-0x3c) extralength=6;
			else if(pos>=0x400-0x3c) extralength=5;
			else if(pos>=0x200-0x3c) extralength=4;
			else if(pos>=0x100-0x3c) extralength=3;
			else if(pos>=0x80-0x3c) extralength=2;
			else if(pos>=0x40-0x3c) extralength=1;
			else extralength=0;

			int extrabits=CSInputNextBitStringLE(input,extralength);
			int offset=(offsetsymbol<<extralength)+extrabits+1;
//			NSLog(@"%x@%d: len %d code %x offset %d",offsetsymbol,(int)pos,extralength,extrabits,offset);

			XADEmitLZSSMatch(self,offset,length,&pos);
		}
	}
}

@end

