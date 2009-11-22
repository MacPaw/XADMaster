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
/*	static const unsigned char AdditionalBitsTable[32]=
	{
		0,0,0,0,1,1,2,2,3,3,4,4,5,5,6,6,7,7,8,8,9,9,10,10,11,11,12,12,13,13,14,14
	};

	static const unsigned int BaseTable[32]=
	{
		0,1,2,3,4,6,8,12,16,24,32,48,64,96,128,192,256,384,512,768,1024,
		1536,2048,3072,4096,6144,8192,12288,16384,24576,32768,49152
	};

	if(pos>=blockend) [self readBlockHeaderAtPosition:pos];

	int symbol=CSInputNextSymbolUsingCodeLE(input,maincode);
	if(symbol<256) return symbol;

	int offsclass=symbol&31;
	int offs=BaseTable[offsclass];
	int offsbits=AdditionalBitsTable[offsclass];

	if(offs==0)
	{
		offs=lastoffs;
	}
	else if(blocktype==3 && offsbits>=3)
	{
		offs+=CSInputNextBitStringLE(input,offsbits-3)<<3;
		offs+=CSInputNextSymbolUsingCodeLE(input,offsetcode);
	}
	else
	{
		offs+=CSInputNextBitStringLE(input,offsbits);
	}

	int lenclass=((symbol-256)>>5)&15;
	int len=BaseTable[lenclass]+3;
	int lenbits=AdditionalBitsTable[lenclass];
	len+=CSInputNextBitStringLE(input,lenbits);

	*offset=offs;
	*length=len;
	lastoffs=offs;

	return XADLZSSMatch;*/
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

		precode=[[XADPrefixCode alloc] initWithLengths:prelengths
		numberOfSymbols:20 maximumLength:15 shortestCodeIsZeros:YES];

		int i=0;
		while(i<count)
		{
			int val=CSInputNextSymbolUsingCodeLE(input,precode);
			int n,length;

			if(val<=16)
			{
				n=1;
				length=(lengths[i]+val)%17;
			}
			else if(val==17)
			{
				n=CSInputNextBitStringLE(input,4)+4-fix;
				length=0;
			}
			else if(val==18)
			{
				n=CSInputNextBitStringLE(input,5+fix)+20-fix;
				length=0;
			}
			else if(val==19)
			{
				n=CSInputNextBitStringLE(input,1)+4-fix;
				int newval=CSInputNextSymbolUsingCodeLE(input,precode);
				length=(lengths[i]+newval)%17;
			}

			for(int j=0;j<n;j++) lengths[i+j]=length;
			i+=n;
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
