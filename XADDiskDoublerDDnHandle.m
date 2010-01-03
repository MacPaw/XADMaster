#import "XADDiskDoublerDDnHandle.h"
#import "XADException.h"

@implementation XADDiskDoublerDDnHandle

-(void)resetBlockStream { xor=0; }

-(int)produceBlockAtOffset:(off_t)pos
{
	uint8_t headxor=0;

	uint32_t uncompsize=CSInputNextUInt32BE(input);
	headxor^=uncompsize^(uncompsize>>8)^(uncompsize>>16)^(uncompsize>>24);

	int val1=CSInputNextUInt16BE(input);
	headxor^=val1^(val1>>8);

	int val2=CSInputNextUInt16BE(input);
	headxor^=val2^(val2>>8);

	int compsize3=CSInputNextUInt16BE(input);
	headxor^=compsize3^(compsize3>>8);

	int compsize2=CSInputNextUInt16BE(input);
	headxor^=compsize2^(compsize2>>8);

	int compsize1=CSInputNextUInt16BE(input);
	headxor^=compsize1^(compsize1>>8);

	int flags=CSInputNextByte(input);
	headxor^=flags;

	headxor^=CSInputNextByte(input);

	int datacorrectxor3=CSInputNextByte(input);
	headxor^=datacorrectxor3;

	int datacorrectxor2=CSInputNextByte(input);
	headxor^=datacorrectxor2;

	int datacorrectxor1=CSInputNextByte(input);
	headxor^=datacorrectxor1;

	int uncompcorrectxor=CSInputNextByte(input);
	headxor^=uncompcorrectxor;

	headxor^=CSInputNextByte(input);

	int headcorrectxor=CSInputNextByte(input);
	if(headxor!=headcorrectxor) [XADException raiseIllegalDataException];

	off_t nextblock=CSInputBufferOffset(input)+compsize1+compsize2+compsize3;

xor^=uncompcorrectxor;
	NSLog(@"%d (%d %d) %d %d %d %x <%x %x %x %x(acc %x)>",uncompsize,val1,val2,compsize3,compsize2,compsize1,
	flags,datacorrectxor3,datacorrectxor2,datacorrectxor1,uncompcorrectxor,xor);

	CSInputSeekToBufferOffset(input,nextblock);

	[self setBlockPointer:outbuffer];
	return uncompsize;
}

@end
