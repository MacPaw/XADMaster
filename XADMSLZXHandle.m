#import "XADMSLZXHandle.h"
#import "XADException.h"

@implementation XADMSLZXHandle

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length windowBits:(int)windowbits
{
	if(self=[super initWithHandle:handle length:length windowSize:1<<windowbits])
	{
		if(windowbits==21) numslots=50;
		else if(windowbits==20) numslots=42;
		else numslots=windowbits*2;

		maincode=lengthcode=offsetcode=nil;
		ispreprocessed=NO;
	}
	return self;
}

-(void)dealloc
{
	[maincode release];
	[lengthcode release];
	[offsetcode release];
	[super dealloc];
}

-(void)resetLZSSHandle
{
	ispreprocessed=CSInputNextBitLE(input);
	if(ispreprocessed)
	{
		preprocessoffset=CSInputNextBitStringLE(input,16)<<16;
		preprocessoffset|=CSInputNextBitStringLE(input,16);
	}

[self readBlockHeader];

	r0=r1=r2=1;
	memset(mainlengths,0,sizeof(mainlengths));
	memset(lengthlengths,0,sizeof(lengthlengths));
}

-(int)nextLiteralOrOffset:(int *)offset andLength:(int *)length atPosition:(off_t)pos
{
/*	int symbol=CSInputNextSymbolUsingCodeLE(input,maincode);
	if(symbol<256) return symbol;

	int offset=CSInputNextSymbolUsingCodeLE(input,lengthcode);
	int actual;
	if(offset==0)
	{
		actual=r0;
	}
	else if(offset==1)
	{
		actual=r1;
		r1=r0;
		r0=actual;
	}
	else if(offset==2)
	{
		actual=r2;
		r2=r0;
		r0=actual;
	}
	else
	{
		actual=offset-2;
		r2=r1;
		r1=r0;
		r0=actual;
	}

	if(CSInputNextBitLE(input))
	{
		if(literals) return CSInputNextSymbolUsingCodeLE(input,literalcode);
		else return CSInputNextBitStringLE(input,8);
	}
	else
	{
		*offset=CSInputNextBitStringLE(input,offsetbits);
		*offset|=CSInputNextSymbolUsingCodeLE(input,offsetcode)<<offsetbits;
		*offset+=1;

		*length=CSInputNextSymbolUsingCodeLE(input,lengthcode)+2;
		if(*length==65) *length+=CSInputNextBitStringLE(input,8);
		if(literals) (*length)++;

		return XADLZSSMatch;
	}*/
}

-(void)readBlockHeader
{
	[maincode release];
	[lengthcode release];
	[offsetcode release];
	maincode=lengthcode=offsetcode=nil;

	blocktype=CSInputNextBitStringLE(input,3);
	if(blocktype<1||blocktype>3) [XADException raiseIllegalDataException];

	switch(blocktype)
	{
		case 2: // aligned offset
		{
			int codelengths[8];
			for(int i=0;i<8;i++) codelengths[i]=CSInputNextBitStringLE(input,3);

			offsetcode=[[XADPrefixCode alloc] initWithLengths:codelengths
			numberOfSymbols:8 maximumLength:7 shortestCodeIsZeros:NO];
		} // fall through

		case 1: // verbatim
		{
			blocksize=CSInputNextBitStringLE(input,8)<<16;
			blocksize|=CSInputNextBitStringLE(input,8)<<8;
			blocksize|=CSInputNextBitStringLE(input,8);

NSLog(@"%d %d",blocktype,blocksize);

			[self readDeltaLengths:&mainlengths[0] count:256 alternateMode:NO];
			[self readDeltaLengths:&mainlengths[256] count:numslots*8 alternateMode:NO];

			maincode=[[XADPrefixCode alloc] initWithLengths:mainlengths
			numberOfSymbols:256+numslots*8 maximumLength:16 shortestCodeIsZeros:NO];

			[self readDeltaLengths:&lengthlengths[0] count:249 alternateMode:NO];
			lengthcode=[[XADPrefixCode alloc] initWithLengths:mainlengths
			numberOfSymbols:249 maximumLength:16 shortestCodeIsZeros:NO];
		}
		break;

		case 3: // uncompressed
			blocksize=CSInputNextBitStringLE(input,8)<<16;
			blocksize|=CSInputNextBitStringLE(input,8)<<8;
			blocksize|=CSInputNextBitStringLE(input,8);
			CSInputSkipTo16BitBoundary(input);
			r0=CSInputNextUInt32LE(input);
			r1=CSInputNextUInt32LE(input);
			r2=CSInputNextUInt32LE(input);
		break;
	}
}

-(void)readDeltaLengths:(int *)lengths count:(int)count alternateMode:(BOOL)altmode;
{
	XADPrefixCode *precode=nil;
	int fix=altmode?1:0;

	@try
	{
		int prelengths[20];
		for(int i=0;i<20;i++) prelengths[i]=CSInputNextBitStringLE(input,4);

		precode=[[XADPrefixCode alloc] initWithLengths:prelengths numberOfSymbols:20 maximumLength:15 shortestCodeIsZeros:NO];

		for(int i=0;i<count;i++)
		{
			int val=CSInputNextSymbolUsingCodeLE(input,precode);
			if(val<=16) lengths[i]=(lengths[i]+val)%17;
			else if(val==17)
			{
				int n=CSInputNextBitStringLE(input,4)+4-fix;
				for(int j=0;j<n;j++) lengths[i+j]=0;
				i+=n-1;
			}
			else if(val==18)
			{
				int n=CSInputNextBitStringLE(input,5+fix)+20-fix;
				for(int j=0;j<n;j++) lengths[i+j]=0;
				i+=n-1;
			}
			else if(val==19)
			{
				int n=CSInputNextBitStringLE(input,1)+4-fix;
				int newval=CSInputNextSymbolUsingCodeLE(input,precode);
				for(int j=0;j<n;j++) lengths[i+j]=(lengths[i+j]+newval)%17;
				i+=n-1;
			}
		}

		[precode release];
	}
	@catch(id e)
	{
		[precode release];
		@throw;
	}
}

@end
