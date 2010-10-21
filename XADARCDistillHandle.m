#import "XADARCDistillHandle.h"
#import "XADException.h"

@implementation XADARCDistillHandle

-(id)initWithHandle:(CSHandle *)handle
{
	return [self initWithHandle:handle length:CSHandleMaxLength];
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length
{
	if(self=[super initWithHandle:handle length:length windowSize:2048])
	{
		//code=nil;
	}
	return self;
}

-(void)dealloc
{
	//[code release];
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

NSLog(@"%x",symbol);

		if(symbol<256)
		{
			XADEmitLZSSLiteral(self,0,&pos);
		}
		else if(symbol==256)
		{
			[self endLZSSHandle];
			return;
		}
		else
		{
		}

		XADEmitLZSSLiteral(self,0,&pos);
	}
}

@end

