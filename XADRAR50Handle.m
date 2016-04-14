#import "XADRAR50Handle.h"
#import "XADException.h"

static int ReadLengthWithSymbol(CSInputBuffer *input,int symbol);

@implementation XADRAR50Handle

-(id)initWithRARParser:(XADRAR5Parser *)parent files:(NSArray *)filearray
{
	if((self=[super initWithName:[parent filename]]))
	{
		parser=parent;
		files=[filearray retain];

		InitializeLZSS(&lzss,0x400000);

		maincode=nil;
		offsetcode=nil;
		lowoffsetcode=nil;
		lengthcode=nil;
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
	[super dealloc];
}

-(void)resetBlockStream
{
	file=0;
	lastend=0;
	startnewfile=YES;

	blockbitend=0;
	islastblock=NO;

	RestartLZSS(&lzss);

	lastoffset=0;
	lastlength=0;
	memset(oldoffset,0,sizeof(oldoffset));

	filterstart=CSHandleMaxLength;
	lastfilternum=0;
	currfilestartpos=0;
}


-(int)produceBlockAtOffset:(off_t)pos
{
	if(startnewfile)
	{
		NSDictionary *dict=[files objectAtIndex:file];
		CSInputBuffer *buf=[parser inputBufferWithDictionary:dict];
		[self setInputBuffer:buf];

		file++;

		[self readBlockHeader];

		startnewfile=NO;
	}

	if(lastend==filterstart)
	{
/*		XADRAR30Filter *firstfilter=[stack objectAtIndex:0];
		off_t start=filterstart;
		int length=[firstfilter length];
		off_t end=start+length;

		// Remove the filter start marker and unpack enough data to run the filter on.
		filterstart=CSHandleMaxLength;
		off_t actualend=[self expandToPosition:end];
		if(actualend!=end) [XADException raiseIllegalDataException];

		// Copy data to virtual machine memory and run the first filter.
		uint8_t *memory=[vm memory];
		CopyBytesFromLZSSWindow(&lzss,memory,start,length);

		[firstfilter executeOnVirtualMachine:vm atPosition:pos-currfilestartpos];

		uint32_t lastfilteraddress=[firstfilter filteredBlockAddress];
		uint32_t lastfilterlength=[firstfilter filteredBlockLength];

		[stack removeObjectAtIndex:0];

		// Run any furhter filters that match the exact same range of data,
		// taking into account that the length may have changed.
		for(;;)
		{
			if([stack count]==0) break;
			XADRAR30Filter *filter=[stack objectAtIndex:0];

			// Check if this filter applies.
			if([filter startPosition]!=filterstart) break;
			if([filter length]!=lastfilterlength) break;

			// Move last filtered block into place and run.
			memmove(&memory[0],&memory[lastfilteraddress],lastfilterlength);

			[filter executeOnVirtualMachine:vm atPosition:pos];

			lastfilteraddress=[filter filteredBlockAddress];
			lastfilterlength=[filter filteredBlockLength];

			[stack removeObjectAtIndex:0];
		}

		// If there are further filters on the stack, set up the filter start marker again
		// and sanity-check filter ordering.
		if([stack count])
		{
			XADRAR30Filter *filter=[stack objectAtIndex:0];
			filterstart=[filter startPosition];

			if(filterstart<end) [XADException raiseIllegalDataException];
		}

		[self setBlockPointer:&memory[lastfilteraddress]];

		lastend=end;

		return lastfilterlength;*/
		return 0;
	}
	else
	{
		off_t start=lastend;
		off_t end=start+0x40000;
		off_t windowend=NextLZSSWindowEdgeAfterPosition(&lzss,start);
		if(end>windowend) end=windowend;

		off_t actualend=[self expandToPosition:end];

		[self setBlockPointer:LZSSWindowPointerForPosition(&lzss,pos)];

		lastend=actualend;

		// Check if we immediately hit a new filter or file edge, and try again.
		if(actualend==start) return [self produceBlockAtOffset:pos];
		else return (int)(actualend-start);
	}
}

-(off_t)expandToPosition:(off_t)end
{
	if(filterstart<end) end=filterstart; // Make sure we stop when we reach a filter.

	for(;;)
	{
//		off_t offs_=CSInputBufferBitOffset(input);
//		NSLog(@"%lld",offs_);
		while(CSInputBufferBitOffset(input)>=blockbitend)
		{
			if(islastblock)
			{
				startnewfile=YES;
				return LZSSPosition(&lzss);
			}
			else
			{
				[self readBlockHeader];
			}
		}

		if(LZSSPosition(&lzss)>=end) return end;

		int symbol=CSInputNextSymbolUsingCode(input,maincode);
		int offs,len;

		if(symbol<256)
		{
			EmitLZSSLiteral(&lzss,symbol);
			continue;
		}
		else if(symbol==256)
		{
			[XADException raiseNotSupportedException];
			continue;
		}
		else if(symbol==257)
		{
			if(filterstart<end) end=filterstart; // Make sure we stop when we reach a filter.
			continue;
		}
		else if(symbol==257)
		{
			if(lastlength==0) continue;

			offs=lastoffset;
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

		lastoffset=offs;
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
