#import "XADZipImplodeHandle.h"
#import "XADException.h"

#import "CSMemoryHandle.h"


@implementation XADZipImplodeHandle

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length
largeDictionary:(BOOL)largedict literalTree:(BOOL)hasliterals
{
	if(self=[super initWithHandle:handle length:length])
	{
		if(largedict)
		{
			dictionarywindow=malloc(8192);
			dictionarymask=8191;
			offsetbits=7;
		}
		else
		{
			dictionarywindow=malloc(4096);
			dictionarymask=4095;
			offsetbits=6;
		}

		literaltree=lengthtree=offsettree=nil;

		@try
		{
			if(hasliterals) literaltree=[[self parseImplodeTreeOfSize:256 handle:handle] retain];
			lengthtree=[[self parseImplodeTreeOfSize:64 handle:handle] retain];
			offsettree=[[self parseImplodeTreeOfSize:64 handle:handle] retain];
		} @catch(id e) {
			NSLog(@"Error parsing prefix trees for implode algorithm: %@",e);
			[self release];
			return nil;
		}

		CSInputSetStartOffset(input,[handle offsetInFile]);
	}
	return self;
}

-(void)dealloc
{
	free(dictionarywindow);
	[literaltree release];
	[lengthtree release];
	[offsettree release];
	[super dealloc];
}

-(XADPrefixTree *)parseImplodeTreeOfSize:(int)size handle:(CSHandle *)fh
{
	int numgroups=[fh readUInt8]+1;

	int codelength[numgroups];
	int numcodes[numgroups];
	int valuestart[numgroups];
	int totalcodes=0;

	for(int i=0;i<numgroups;i++)
	{
		int val=[fh readUInt8];

		codelength[i]=(val&0x0f)+1;
		numcodes[i]=(val>>4)+1;
		valuestart[i]=totalcodes;
//NSLog(@"len %d,num %d, start %d",codelength[i],numcodes[i],valuestart[i]);
		totalcodes+=numcodes[i];
	}

	if(totalcodes!=size) [XADException raiseIllegalDataException];

	XADPrefixTree *tree=[XADPrefixTree prefixTree];

	int prevlength=17;
	int code=0;

	for(int length=16;length>=1;length--)
	for(int n=numgroups-1;n>=0;n--)
	{
		if(codelength[n]!=length) continue;

		int num=numcodes[n];
		int start=valuestart[n];

		for(int j=num-1;j>=0;j--)
		{
//NSLog(@"-->%d: %x %d",start+j,code,length);
			[tree addValue:start+j forCode:code>>16-length length:length];
			code+=1<<16-length;
		}

		prevlength=length;
	}

	return tree;
}

-(void)resetByteStream
{
	dictionarylen=0;
	dictionaryoffs=0;
	memset(dictionarywindow,0,dictionarymask+1);
}

-(uint8_t)produceByteAtOffset:(off_t)pos
{
	if(!dictionarylen)
	{
		int bit=CSInputNextBitLE(input);
		if(bit)
		{
			uint8_t byte;
			if(literaltree) byte=CSInputNextSymbolFromTreeLE(input,literaltree);
			else byte=CSInputNextBitStringLE(input,8);

			return dictionarywindow[pos&dictionarymask]=byte;
		}
		else
		{
			int offset=CSInputNextBitStringLE(input,offsetbits);
			offset|=CSInputNextSymbolFromTreeLE(input,offsettree)<<offsetbits;

			dictionaryoffs=pos-offset-1;

			dictionarylen=CSInputNextSymbolFromTreeLE(input,lengthtree)+2;
			if(dictionarylen==65) dictionarylen+=CSInputNextBitStringLE(input,8);
			if(literaltree) dictionarylen++;
		}
	}

	dictionarylen--;
	uint8_t byte=dictionarywindow[dictionaryoffs++&dictionarymask];

	return dictionarywindow[pos&dictionarymask]=byte;
}

@end
