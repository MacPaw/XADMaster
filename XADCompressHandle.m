#import "XADCompressHandle.h"
#import "XADException.h"

@implementation XADCompressHandle

-(id)initWithHandle:(CSHandle *)handle flags:(int)compressflags
{
	return [self initWithHandle:handle length:CSHandleMaxLength flags:compressflags];
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length flags:(int)compressflags
{
	if((self=[super initWithInputBufferForHandle:handle length:length]))
	{
		blockmode=(compressflags&0x80)!=0;

		int maxsymbols=1<<(compressflags&0x1f);
		if(maxsymbols<=256) [XADException raiseDecrunchException];

		lzw=AllocLZW(maxsymbols,blockmode?1:0);
	}
	return self;
}

-(void)dealloc
{
	FreeLZW(lzw);
	[super dealloc];
}

-(void)resetByteStream
{
	ClearLZWTable(lzw);
	symbolcounter=0;
	buffer=bufferend=NULL;
}

-(uint8_t)produceByteAtOffset:(off_t)pos
{
	if(buffer>=bufferend)
	{
		int symbol;
		for(;;)
		{
			if(CSInputAtEOF(input)) CSByteStreamEOF(self);

			symbol=CSInputNextBitStringLE(input,LZWSuggestedSymbolSize(lzw));
			symbolcounter++;
			if(symbol==256&&blockmode)
			{
				// Skip garbage data after a clear. God damn, this is dumb.
				int symbolsize=LZWSuggestedSymbolSize(lzw);
				if(symbolcounter%8) CSInputSkipBitsLE(input,symbolsize*(8-symbolcounter%8));
				ClearLZWTable(lzw);
				symbolcounter=0;
			}
			else break;
		}

		if(NextLZWSymbol(lzw,symbol)==LZWInvalidCodeError) [XADException raiseDecrunchException];

		int n=LZWOutputToInternalBuffer(lzw);
		buffer=LZWInternalBuffer(lzw);
		bufferend=buffer+n;
	}

	return *buffer++;
}

@end
