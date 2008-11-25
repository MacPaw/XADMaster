#import "XADCompactProLZHHandle.h"
#import "XADException.h"

@implementation XADCompactProLZHHandle

-(id)initWithHandle:(CSHandle *)handle blockSize:(int)blocklen
{
	if(self=[super initWithHandle:handle windowSize:8192])
	{
		blocksize=blocklen;
		literaltree=lengthtree=offsettree=nil;
	}
	return self;
}

-(void)dealloc
{
	[literaltree release];
	[lengthtree release];
	[offsettree release];
	[super dealloc];
}

-(void)resetLZSSHandle
{
	blockcount=blocksize;
	blockstart=0;
}

-(int)nextLiteralOrOffset:(int *)offset andLength:(int *)length
{
	@try
	{
		if(blockcount>=blocksize)
		{
			if(blockstart)
			{
				// Don't let your bad implementations leak into your file formats, people!
				CSInputSkipToByteBoundary(input);
				if((CSInputBufferOffset(input)-blockstart)&1) CSInputSkipBytes(input,3);
				else CSInputSkipBytes(input,2);
			}

			[literaltree release];
			[lengthtree release];
			[offsettree release];
			literaltree=lengthtree=offsettree=nil;
			literaltree=[[self parseTreeOfSize:256] retain];
			lengthtree=[[self parseTreeOfSize:64] retain];
			offsettree=[[self parseTreeOfSize:128] retain];
			blockcount=0;
			blockstart=CSInputBufferOffset(input);
		}

		if(CSInputNextBit(input))
		{
			blockcount+=2;
			return CSInputNextSymbolFromTree(input,literaltree);
		}
		else
		{
			blockcount+=3;

			*length=CSInputNextSymbolFromTree(input,lengthtree);

			*offset=CSInputNextSymbolFromTree(input,offsettree)<<6;
			*offset|=CSInputNextBitString(input,6);

			return XADLZSSMatch;
		}
	}
	@catch(id e) { }

	return XADLZSSEnd;
}

-(XADPrefixTree *)parseTreeOfSize:(int)size
{
	int numbytes=CSInputNextByte(input);
	if(numbytes*2>size) [XADException raiseIllegalDataException];

	int codelength[size];

	for(int i=0;i<numbytes;i++)
	{
		int val=CSInputNextByte(input);
		codelength[2*i]=val>>4;
		codelength[2*i+1]=val&0x0f;
	}
	for(int i=numbytes*2;i<size;i++) codelength[i]=0;

	XADPrefixTree *tree=[XADPrefixTree prefixTree];

	int code=0;

	for(int length=15;length>=1;length--)
	for(int n=size-1;n>=0;n--)
	{
		if(codelength[n]!=length) continue;
		// Instead of reversing to get a low-bit-first code, we shift and use high-bit-first.
		[tree addValue:n forCodeWithHighBitFirst:(code^0xffff)>>16-length length:length];
		code+=1<<16-length;
	}

	return tree;
}

@end
