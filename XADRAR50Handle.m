#import "XADRAR50Handle.h"
#import "XADRARFilters.h"
#import "XADException.h"

static int ReadLengthWithSymbol(CSInputBuffer *input,int symbol);
static uint32_t ReadFilterInteger(CSInputBuffer *input);

@implementation XADRAR50Handle

-(id)initWithRARParser:(XADRAR5Parser *)parentparser files:(NSArray *)filearray
{
	if(self=[super initWithParentHandle:[parentparser handle]])
	{
		parser=parentparser;
		files=[filearray retain];

		NSDictionary *dict=[files objectAtIndex:0];

		CSInputBuffer *buf=[parser inputBufferWithDictionary:dict];
		[self setInputBuffer:buf];

		uint64_t dictsize=[[dict objectForKey:@"RAR5DictionarySize"] unsignedLongLongValue];
		if(!InitializeLZSS(&lzss,dictsize)) [XADException raiseOutOfMemoryException];

		maincode=nil;
		offsetcode=nil;
		lowoffsetcode=nil;
		lengthcode=nil;

		filters=[NSMutableArray new];
		filterdata=nil;
	}
	return self;
}

-(void)dealloc
{
	[files release];
	CleanupLZSS(&lzss);
	[maincode release];
	[offsetcode release];
	[lowoffsetcode release];
	[lengthcode release];
	[filters release];
	[filterdata release];
	[super dealloc];
}

-(void)resetBlockStream
{
	file=0;
	startnewfile=YES;
	currfilestartpos=0;

	blockbitend=0;
	islastblock=NO;

	RestartLZSS(&lzss);

	lastlength=0;
	memset(oldoffset,0,sizeof(oldoffset));

	[filters removeAllObjects];
	[filterdata release];
	filterdata=nil;
}


-(int)produceBlockAtOffset:(off_t)pos
{
	if(startnewfile)
	{
		NSDictionary *dict=[files objectAtIndex:file];

		CSInputBuffer *buf=[parser inputBufferWithDictionary:dict];
		[self setInputBuffer:buf];

		uint64_t dictsize=[[dict objectForKey:@"RAR5DictionarySize"] unsignedLongLongValue];
		if(dictsize>LZSSWindowSize(&lzss)) [XADException raiseNotSupportedException];

		file++;

		[self readBlockHeader];

		currfilestartpos=pos;
		startnewfile=NO;
	}

	off_t nextfilterstart=CSHandleMaxLength;
	if([filters count]) nextfilterstart=[(XADRAR50Filter *)[filters objectAtIndex:0] start];

	if(pos==nextfilterstart)
	{
		XADRAR50Filter *filter=[filters objectAtIndex:0];
		off_t start=nextfilterstart;
		uint32_t length=[filter length];
		off_t end=start+length;

		off_t actualend=[self expandToPosition:end];
		if(actualend!=end) [XADException raiseIllegalDataException];

		[filterdata release];
		filterdata=[[NSMutableData dataWithLength:length] retain];
		uint8_t *memory=[filterdata mutableBytes];

		CopyBytesFromLZSSWindow(&lzss,memory,start,length);

		[filter runOnData:filterdata fileOffset:pos-currfilestartpos];

		[filters removeObjectAtIndex:0];

		[self setBlockPointer:memory];

		return length;
	}
	else
	{
		off_t end=pos+0x40000;
		off_t windowend=NextLZSSWindowEdgeAfterPosition(&lzss,pos);
		if(end>windowend) end=windowend;
		if(end>nextfilterstart) end=nextfilterstart; // Make sure we stop when we reach a filter.

		off_t actualend=[self expandToPosition:end];

		[self setBlockPointer:LZSSWindowPointerForPosition(&lzss,pos)];

		// Check if we immediately hit a new filter or file edge, and try again.
		if(actualend==pos) return [self produceBlockAtOffset:pos];
		else return (int)(actualend-pos);
	}
}

-(off_t)expandToPosition:(off_t)end
{
	for(;;)
	{
		if(LZSSPosition(&lzss)>=end) return end;

		while(CSInputBufferBitOffset(input)>=blockbitend)
		{
			if(islastblock)
			{
				startnewfile=YES;
				off_t pos=LZSSPosition(&lzss);
				if(end<pos) return end;
				else return pos;
			}
			else
			{
				[self readBlockHeader];
			}
		}

		int symbol=CSInputNextSymbolUsingCode(input,maincode);
		int offs,len;

		if(symbol<256)
		{
			EmitLZSSLiteral(&lzss,symbol);
			continue;
		}
		else if(symbol==256)
		{
			off_t start=ReadFilterInteger(input)+LZSSPosition(&lzss);
			uint32_t length=ReadFilterInteger(input);
			int type=CSInputNextBitString(input,3);

			XADRAR50Filter *filter=nil;

			switch(type)
			{
				case 0:
				{
					int numchannels=CSInputNextBitString(input,5)+1;
					filter=[[[XADRAR50DeltaFilter alloc] initWithStart:start length:length numberOfChannels:numchannels] autorelease];
				}
				break;

				case 1:
					filter=[[[XADRAR50E8E9Filter alloc] initWithStart:start length:length handleE9:NO] autorelease];
				break;

				case 2:
					filter=[[[XADRAR50E8E9Filter alloc] initWithStart:start length:length handleE9:YES] autorelease];
				break;

				case 3:
					filter=[[[XADRAR50ARMFilter alloc] initWithStart:start length:length] autorelease];
				break;

				default:
					[XADException raiseNotSupportedException];
				break;
			}
			
			[filters addObject:filter];

			if(end>start) end=start; // Make sure we stop when we reach a filter.

			continue;
		}
		else if(symbol==257)
		{
			if(lastlength==0) continue;

			offs=oldoffset[0];
			len=lastlength;
		}
		else if(symbol<262)
		{
			int offsindex=symbol-258;
			offs=oldoffset[offsindex];

			int lensymbol=CSInputNextSymbolUsingCode(input,lengthcode);
			len=ReadLengthWithSymbol(input,lensymbol);

			for(int i=offsindex;i>0;i--) oldoffset[i]=oldoffset[i-1];
			oldoffset[0]=offs;

		}
		else //if(symbol>=262)
		{
			len=ReadLengthWithSymbol(input,symbol-262);

			int offssymbol=CSInputNextSymbolUsingCode(input,offsetcode);
			if(offssymbol<4)
			{
				offs=offssymbol+1;
			}
			else
			{
				int offsbits=offssymbol/2-1;
				int offslow;

				if(offsbits>=4)
				{
					if(offsbits>4) offslow=CSInputNextBitString(input,offsbits-4)<<4;
					else offslow=0;
					offslow+=CSInputNextSymbolUsingCode(input,lowoffsetcode);
				}
				else
				{
					offslow=CSInputNextBitString(input,offsbits);
				}

				offs=((2+(offssymbol&1))<<offsbits)+offslow+1;
			}

			if(offs>0x40000) len++;
			if(offs>0x2000) len++;
			if(offs>0x100) len++;

			for(int i=3;i>0;i--) oldoffset[i]=oldoffset[i-1];
			oldoffset[0]=offs;
		}

		lastlength=len;

		EmitLZSSMatch(&lzss,offs,len);
	}
}

-(void)readBlockHeader
{
	CSInputSkipToByteBoundary(input);

	int checksum=0x5a;

	int flags=CSInputNextByte(input);
	checksum^=flags;

	int sizecount=((flags>>3)&3)+1;

	if(sizecount==4) [XADException raiseDecrunchException]; // TODO: What to do here?

	int blockbitsize=(flags&7)+1;

	int correctchecksum=CSInputNextByte(input);

	uint32_t blocksize=0;
	for (int i=0;i<sizecount;i++)
	{
		int byte=CSInputNextByte(input);
		blocksize+=byte<<(i*8);
		checksum^=byte;
	}

	if(checksum!=correctchecksum) [XADException raiseDecrunchException];

	blockbitend=CSInputBufferBitOffset(input)+blocksize*8+blockbitsize-8;
	islastblock=flags&0x40;

	if(flags&0x80) [self allocAndParseCodes];
}

-(void)allocAndParseCodes
{
	[maincode release]; maincode=nil;
	[offsetcode release]; offsetcode=nil;
	[lowoffsetcode release]; lowoffsetcode=nil;
	[lengthcode release]; lengthcode=nil;

	XADPrefixCode *precode=nil;
	@try
	{
		int prelengths[20];
		for(int i=0;i<20;)
		{
			int length=CSInputNextBitString(input,4);
			if(length==15)
			{
				int count=CSInputNextBitString(input,4)+2;

				if(count==2) prelengths[i++]=15;
				else for(int j=0;j<count && i<20;j++) prelengths[i++]=0;
			}
			else prelengths[i++]=length;
		}

		precode=[[XADPrefixCode alloc] initWithLengths:prelengths
		numberOfSymbols:20 maximumLength:15 shortestCodeIsZeros:YES];

		for(int i=0;i<306+64+16+44;)
		{
			int val=CSInputNextSymbolUsingCode(input,precode);
			if(val<16)
			{
				lengthtable[i]=val;
				i++;
			}
			else if(val<18)
			{
				if(i==0) [XADException raiseDecrunchException];

				int n;
				if(val==16) n=CSInputNextBitString(input,3)+3;
				else n=CSInputNextBitString(input,7)+11;

				for(int j=0;j<n && i<306+64+16+44;j++)
				{
					lengthtable[i]=lengthtable[i-1];
					i++;
				}
			}
			else //if(val<20)
			{
				int n;
				if(val==18) n=CSInputNextBitString(input,3)+3;
				else n=CSInputNextBitString(input,7)+11;

				for(int j=0;j<n && i<306+64+16+44;j++) lengthtable[i++]=0;
			}
		}

		[precode release];
	}
	@catch(id e)
	{
		[precode release];
		@throw;
	}

	maincode=[[XADPrefixCode alloc] initWithLengths:&lengthtable[0]
	numberOfSymbols:306 maximumLength:15 shortestCodeIsZeros:YES];

	offsetcode=[[XADPrefixCode alloc] initWithLengths:&lengthtable[306]
	numberOfSymbols:64 maximumLength:15 shortestCodeIsZeros:YES];

	lowoffsetcode=[[XADPrefixCode alloc] initWithLengths:&lengthtable[306+64]
	numberOfSymbols:16 maximumLength:15 shortestCodeIsZeros:YES];

	lengthcode=[[XADPrefixCode alloc] initWithLengths:&lengthtable[306+64+16]
	numberOfSymbols:44 maximumLength:15 shortestCodeIsZeros:YES];
}

@end




static int ReadLengthWithSymbol(CSInputBuffer *input,int symbol)
{
	if(symbol<8)
	{
		return symbol+2;
	}
	else
	{
		int lenbits=symbol/4-1;
		int length=((4+(symbol&3))<<lenbits)+2;
		length+=CSInputNextBitString(input,lenbits);
		return length;
	}
}

static uint32_t ReadFilterInteger(CSInputBuffer *input)
{
	int count=CSInputNextBitString(input,2)+1;

	uint32_t value=0;
	for(int i=0;i<count;i++) value+=CSInputNextBitString(input,8)<<(i*8);

	return value;
}

