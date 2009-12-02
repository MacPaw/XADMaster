#import "XADMSLZXHandle.h"
#import "XADException.h"
#import "XADLZXHandle.h"

@implementation XADMSLZXHandle

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length windowBits:(int)windowbits
{
	if(self=[super initWithHandle:[[[XADLZXSwapHandle alloc] initWithHandle:handle] autorelease] length:length windowSize:1<<windowbits])
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
	ispreprocessed=CSInputNextBit(input);
	if(ispreprocessed)
	{
		preprocessoffset=CSInputNextBitString(input,16)<<16;
		preprocessoffset|=CSInputNextBitString(input,16);
	}

	r0=r1=r2=1;
	blocktype=0;
	blockend=0;
	memset(mainlengths,0,sizeof(mainlengths));
	memset(lengthlengths,0,sizeof(lengthlengths));
}

-(int)nextLiteralOrOffset:(int *)offset andLength:(int *)length atPosition:(off_t)pos
{
	static const unsigned char AdditionalBitsTable[50]=
	{
		0,0,0,0,1,1,2,2,3,3,4,4,5,5,6,6,7,7,8,8,9,9,10,10,11,11,12,12,13,13,14,14,
		15,15,16,16,17,17,17,17,17,17,17,17,17,17,17,17,17,17
	};

	static const unsigned int BaseTable[50]=
	{
		0,1,2,3,4,6,8,12,16,24,32,48,64,96,128,192,256,384,512,768,1024,
		1536,2048,3072,4096,6144,8192,12288,16384,24576,32768,49152,
		65536,98304,131072,196608,262144,393216,524288,655360,786432,917504,
		1048576,1179648,1310720,1441792,1572864,1703936,1835008,1966080
	};

	if(blocktype!=3 && (pos&0x7fff)==0 && pos!=0) CSInputSkipTo16BitBoundary(input);

	if(pos>=blockend) [self readBlockHeaderAtPosition:pos];

	if(blocktype==3) return CSInputNextByte(input);

	int symbol=CSInputNextSymbolUsingCode(input,maincode);
	if(symbol<256) return symbol;

	int len=(symbol&7)+2;
	if(len==9) len=CSInputNextSymbolUsingCode(input,lengthcode)+9;

	int offsclass=(symbol-256)>>3;
	int offs=BaseTable[offsclass];
	int offsbits=AdditionalBitsTable[offsclass];

	if(offs==0)
	{
		offs=r0;
	}
	else if(offs==1)
	{
		offs=r1;
		r1=r0;
		r0=offs;
	}
	else if(offs==2)
	{
		offs=r2;
		r2=r0;
		r0=offs;
	}
	else
	{
		if(blocktype==2 && offsbits>=3)
		{
			offs+=CSInputNextBitString(input,offsbits-3)<<3;
			offs+=CSInputNextSymbolUsingCode(input,offsetcode);
		}
		else
		{
			offs+=CSInputNextBitString(input,offsbits);
		}

		offs-=2;
		r2=r1;
		r1=r0;
		r0=offs;
	}

	*offset=offs;
	*length=len;

//fprintf(stderr,"%d:%d\n",len,offs);

	return XADLZSSMatch;
}

-(void)readBlockHeaderAtPosition:(off_t)pos
{
	[maincode release];
	[lengthcode release];
	[offsetcode release];
	maincode=lengthcode=offsetcode=nil;

	if(blocktype==3) CSInputSkipTo16BitBoundary(input);

	blocktype=CSInputNextBitString(input,3);
	if(blocktype<1||blocktype>3) [XADException raiseIllegalDataException];

	int blocksize=CSInputNextBitString(input,24);
	blockend=pos+blocksize;

	switch(blocktype)
	{
		case 2: // aligned offset
		{
			int codelengths[8];
			for(int i=0;i<8;i++) codelengths[i]=CSInputNextBitString(input,3);

			offsetcode=[[XADPrefixCode alloc] initWithLengths:codelengths
			numberOfSymbols:8 maximumLength:7 shortestCodeIsZeros:YES];
		} // fall through

		case 1: // verbatim
		{
			[self readDeltaLengths:&mainlengths[0] count:256 alternateMode:NO];
			[self readDeltaLengths:&mainlengths[256] count:numslots*8 alternateMode:NO];

			maincode=[[XADPrefixCode alloc] initWithLengths:mainlengths
			numberOfSymbols:256+numslots*8 maximumLength:16 shortestCodeIsZeros:YES];

			[self readDeltaLengths:lengthlengths count:249 alternateMode:NO];
			lengthcode=[[XADPrefixCode alloc] initWithLengths:lengthlengths
			numberOfSymbols:249 maximumLength:16 shortestCodeIsZeros:YES];
		}
		break;

		case 3: // uncompressed
		{
			CSInputSkipTo16BitBoundary(input);
			r0=CSInputNextUInt32LE(input);
			r1=CSInputNextUInt32LE(input);
			r2=CSInputNextUInt32LE(input);
		}
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
		for(int i=0;i<20;i++) prelengths[i]=CSInputNextBitString(input,4);

		precode=[[XADPrefixCode alloc] initWithLengths:prelengths
		numberOfSymbols:20 maximumLength:15 shortestCodeIsZeros:YES];

		int i=0;
		while(i<count)
		{
			int val=CSInputNextSymbolUsingCode(input,precode);
			int n,length;

			if(val<=16)
			{
				n=1;
				length=(lengths[i]+17-val)%17;
			}
			else if(val==17)
			{
				n=CSInputNextBitString(input,4)+4-fix;
				length=0;
			}
			else if(val==18)
			{
				n=CSInputNextBitString(input,5+fix)+20-fix;
				length=0;
			}
			else if(val==19)
			{
				n=CSInputNextBitString(input,1)+4-fix;
				int newval=CSInputNextSymbolUsingCode(input,precode);
				length=(lengths[i]+17-newval)%17;
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
