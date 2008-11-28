#import "XADDeflateHandle.m"

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length windowSize:(int)windowsize
{
	if(self=[super initWithHandle:handle length:length windowSize:windowsize])
	{
		literaltree=offsettree=nil;
	}
	return self;
}

-(void)dealloc
{
	[literaltree release];
	[offsettree release];
	[super dealloc];
}

-(void)resetLZSSHandle
{
	[self readBlockHeader];
}

-(int)nextLiteralOrOffset:(int *)offset andLength:(int *)length
{
	if(storedcount)
	{
		storedcount--;
		return CSInputNextByte(input);
	}

	if(!literaltree)
	{

	int literal=CSInputNextSymbolFromTreeLE(input,literaltree);
	if(literal<256) return literal;
	else if(literal==256)
	{
		[self readBlockHeader];
		return [self nextLiteralOrOffset:offset andLength:length];
	}
	else if(literal<) *length=;
	else
}

-(void)readBlockHeader
{
	[literaltree release];
	[offsettree release];

	int type=CSInputNextBitStringLE(input,2);
	switch(type)
	{
		case 0: // stored
		{
			int count=CSInputNextUInt16LE(input);
			if(count!=~CSInputNextUInt16LE(input)) [XADException raiseDecrunchException];
			storedcount=count-1;
			return CSInputNextByte();
		}
		break;

		case 1: // fixed huffman
		break;

		case 2: // dynamic huffman
		break;

		default: [XADException raiseDecrunchException];
	}
}
