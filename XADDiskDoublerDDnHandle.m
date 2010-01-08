#import "XADDiskDoublerDDnHandle.h"
#import "XADException.h"

static void CopyBytesWithRepeat(uint8_t *dest,uint8_t *src,int length)
{
	for(int i=0;i<length;i++) dest[i]=src[i];
}

@implementation XADDiskDoublerDDnHandle

-(void)resetBlockStream
{
	[self setBlockPointer:outbuffer];

	checksumcorrect=YES;
}

-(int)produceBlockAtOffset:(off_t)pos
{
	NSAutoreleasePool *pool=[NSAutoreleasePool new];

	uint8_t headxor=0;

	uint32_t uncompsize=CSInputNextUInt32BE(input);
	if(uncompsize>sizeof(outbuffer)) [XADException raiseIllegalDataException];
	headxor^=uncompsize^(uncompsize>>8)^(uncompsize>>16)^(uncompsize>>24);

	int numliterals=CSInputNextUInt16BE(input);
	headxor^=numliterals^(numliterals>>8);

	int numoffsets=CSInputNextUInt16BE(input);
	headxor^=numoffsets^(numoffsets>>8);

	int lengthcompsize=CSInputNextUInt16BE(input);
	headxor^=lengthcompsize^(lengthcompsize>>8);

	int literalcompsize=CSInputNextUInt16BE(input);
	headxor^=literalcompsize^(literalcompsize>>8);

	int offsetcompsize=CSInputNextUInt16BE(input);
	headxor^=offsetcompsize^(offsetcompsize>>8);

	int flags=CSInputNextByte(input);
	headxor^=flags;

	headxor^=CSInputNextByte(input);

	int datacorrectxor1=CSInputNextByte(input);
	headxor^=datacorrectxor1;

	int datacorrectxor2=CSInputNextByte(input);
	headxor^=datacorrectxor2;

	int datacorrectxor3=CSInputNextByte(input);
	headxor^=datacorrectxor3;

	int uncompcorrectxor=CSInputNextByte(input);
	headxor^=uncompcorrectxor;

	headxor^=CSInputNextByte(input);

	int headcorrectxor=CSInputNextByte(input);
	if(headxor!=headcorrectxor) [XADException raiseIllegalDataException];

	NSLog(@"%d (%d %d) %d %d %d %x <%x %x %x %x>",uncompsize,numliterals,numoffsets,lengthcompsize,literalcompsize,offsetcompsize,
	flags,datacorrectxor1,datacorrectxor2,datacorrectxor3,uncompcorrectxor);

	if(flags&0x40)
	{
		// Uncompressed block
		for(int i=0;i<uncompsize;i++) outbuffer[i]=CSInputNextByte(input);
	}
	else
	{
		off_t literalstart=CSInputBufferOffset(input)+offsetcompsize;
		off_t lengthstart=literalstart+literalcompsize;
		off_t nextblock=lengthstart+lengthcompsize;

		int offsets[numoffsets];

		XADPrefixCode *offsetcode=[self readCode];

		for(int i=0;i<numoffsets;i++)
		{
			int slot=CSInputNextSymbolUsingCode(input,offsetcode);

			if(slot<4)
			{
				offsets[i]=slot+1;
			}
			else
			{
				int bits=slot/2-1;
				int start=((2+(slot&1))<<bits)+1;
				offsets[i]=start+CSInputNextBitString(input,bits);
			}

//NSLog(@"%d",offsets[i]);
		}

		CSInputSeekToBufferOffset(input,literalstart);

		uint8_t *literalptr=&outbuffer[uncompsize-numliterals];

		if(flags&0x80)
		{
			XADPrefixCode *literalcode=[self readCode];

			// Compressed literals
			for(int i=0;i<numliterals;i++) literalptr[i]=CSInputNextSymbolUsingCode(input,literalcode);
		}
		else
		{
			// Uncompressed literals
			for(int i=0;i<numliterals;i++) literalptr[i]=CSInputNextByte(input);
		}

		CSInputSeekToBufferOffset(input,lengthstart);

		XADPrefixCode *lengthcode=[self readCode];

		int *offsetptr=offsets;

		int currpos=0;
		while(currpos<uncompsize)
		{
			int code=CSInputNextSymbolUsingCode(input,lengthcode);
			if(code==0)
			{
				// check for literals left

				outbuffer[currpos++]=*literalptr++;
			}
			else if(code<128)
			{
				int length=code+2;

				// check for offsets left
				int offset=*offsetptr++;

				if(offset>currpos) [XADException raiseIllegalDataException];
				if(currpos+length>uncompsize) [XADException raiseIllegalDataException]; //length=uncompsize-currpos;

				CopyBytesWithRepeat(&outbuffer[currpos],&outbuffer[currpos-offset],length);
				currpos+=length;
			}
			else
			{
				int length=1<<(code-128);

				if(currpos+length>uncompsize) [XADException raiseIllegalDataException]; //length=uncompsize-currpos;
				// check for literals left

				memmove(&outbuffer[currpos],literalptr,length);
				currpos+=length;
				literalptr+=length;
			}
		}

		CSInputSeekToBufferOffset(input,nextblock);
	}

	int uncompxor=0;
	for(int i=0;i<uncompsize;i++) uncompxor^=outbuffer[i];

	if(uncompxor!=uncompcorrectxor) checksumcorrect=NO;

	[pool release];

	return uncompsize;
}

-(XADPrefixCode *)readCode
{
	uint32_t head=CSInputNextUInt32BE(input);

	int numcodes=((head>>24)&0xff)+1;
	int numbytes=(head>>13)&0x7ff;
	int maxlength=(head>>8)&0x1f;
	int numbits=(head>>3)&0x1f;
	int codelengths[numcodes];

	off_t end=CSInputBufferOffset(input)+numbytes;

NSLog(@"%08x %d %d %d",head,numcodes,numbits,maxlength);

	if(head&0x04) // uses zero coding
	{
		for(int i=0;i<numcodes;i++)
		{
			if(CSInputNextBit(input))
			{
				codelengths[i]=CSInputNextBitString(input,numbits);
				if(codelengths[i]>maxlength) [XADException raiseIllegalDataException];
			}
			else codelengths[i]=0;
		}
	}
	else
	{
		for(int i=0;i<numcodes;i++)
		{
			codelengths[i]=CSInputNextBitString(input,numbits);
			if(codelengths[i]>maxlength) [XADException raiseIllegalDataException];
		}
	}

	CSInputSeekToBufferOffset(input,end);

	return [XADPrefixCode prefixCodeWithLengths:codelengths numberOfSymbols:numcodes
	maximumLength:maxlength shortestCodeIsZeros:YES];
}

-(BOOL)hasChecksum { return YES; }

-(BOOL)isChecksumCorrect { return checksumcorrect; }

@end
