#import "XADSqueezeHandle.h"
#import "XADException.h"

@implementation XADSqueezeHandle

// TODO: decode tree to a XADPrefixCode for speed.

-(void)resetByteStream
{
	int numnodes=CSInputNextUInt16LE(input)*2;

	if(numnodes>=257*2) [XADException raiseDecrunchException];

	nodes[0]=nodes[1]=-(256+1);

	for(int i=0;i<numnodes;i++) nodes[i]=CSInputNextInt16LE(input);
	//if(nodes[i]>) [XADException raiseDecrunchException];
}

-(uint8_t)produceByteAtOffset:(off_t)pos
{
	int val=0;
	while(val>=0)
	{
		if(!CSInputBitsLeftInBuffer(input)) CSByteStreamEOF(self);
		val=nodes[2*val+CSInputNextBitLE(input)];
	}

	int output=-(val+1);

	if(output==256) CSByteStreamEOF(self);

	return output;
}

@end
