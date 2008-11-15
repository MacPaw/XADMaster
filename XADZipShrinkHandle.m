#import "XADZipShrinkHandle.h"
#import "XADException.h"


@implementation XADZipShrinkHandle

static uint8_t FindFirstByte(XADZipShrinkTreeNode *nodes,int symbol)
{
	while(nodes[symbol].parent>=0) symbol=nodes[symbol].parent;
	return nodes[symbol].chr;
}

static int FillBuffer(uint8_t *buffer,XADZipShrinkTreeNode *nodes,int symbol)
{
	if(symbol<0) return 0;

	int num=FillBuffer(buffer,nodes,nodes[symbol].parent);
	buffer[num]=nodes[symbol].chr;
	return num+1;
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length
{
	if(self=[super initWithHandle:handle length:length])
	{
		nodes=malloc(sizeof(XADZipShrinkTreeNode)*8192);
		symbolsize=9;

		for(int i=0;i<256;i++)
		{
			nodes[i].chr=i;
			nodes[i].parent=-1;
		}
	}
	return self;
}

-(void)dealloc
{
	free(nodes);
	[super dealloc];
}

-(void)clearTable
{
	numsymbols=257;
	prevsymbol=-1;
	currbyte=numbytes=0;
}

-(void)resetFilter
{
	[self clearTable];
	CSFilterStartReadingBitsLE(self);
}

-(uint8_t)produceByteAtOffset:(off_t)pos
{
	if(currbyte>=numbytes)
	{
		int symbol;
		for(;;)
		{
			symbol=CSFilterNextBitStringLE(self,symbolsize);
			if(symbol==256)
			{
				int next=CSFilterNextBitStringLE(self,symbolsize);
				if(next==1)
				{
					symbolsize++;
					if(symbolsize>13) [XADException raiseDecrunchException];
				}
				else if(next==2) [self clearTable];
			}
			else break;
		}

		//if(symbol==257) CSFilterEOF();

		if(prevsymbol<0)
		{
			prevsymbol=symbol;
			return symbol;
		}
		else
		{
			if(numsymbols==8192) [XADException raiseDecrunchException];

			int outputsymbol,prefixsymbol,postfixbyte;
			if(symbol<numsymbols) // does <code> exist in the string table?
			{
				outputsymbol=symbol; // output the string for <code> to the charstream;

				prefixsymbol=prevsymbol; // [...] <- translation for <old>;
				postfixbyte=FindFirstByte(nodes,symbol); // K <- first character of translation for <code>;
				// add [...]K to the string table;
			}
			else if(symbol==numsymbols)
			{
				prefixsymbol=prevsymbol; // [...] <- translation for <old>;
				postfixbyte=FindFirstByte(nodes,prevsymbol); // K <- first character of [...];

				outputsymbol=numsymbols; // output [...]K to charstream and add it to string table;
			}
			else
			{
				[XADException raiseDecrunchException];
			}

			nodes[numsymbols].parent=prefixsymbol;
			nodes[numsymbols].chr=postfixbyte;
			numsymbols++;

			prevsymbol=symbol;

			numbytes=FillBuffer(buffer,nodes,outputsymbol);
			currbyte=1;

			return buffer[0];
		}
	}
	else
	{
		return buffer[currbyte++];
	}
}

@end
