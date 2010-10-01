#import "XADDiskDoublerMethod2Handle.h"
#import "XADException.h"

@implementation XADDiskDoublerMethod2Handle

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length numberOfContexts:(int)num
{
	if(self=[super initWithHandle:handle length:length])
	{
		numcontexts=num;
	}
	return self;
}

-(void)resetByteStream
{
	for(int i=0;i<numcontexts;i++)
	{
		for(int j=0;j<256;j++)
		{
			contexts[i].sometable[2*j]=j;
			contexts[i].sometable[2*j+1]=j;
			contexts[i].eventable[j]=j*2;
			contexts[i].oddtable[j]=j*2+1;
		}
	}

	currcontext=0;
}

-(uint8_t)produceByteAtOffset:(off_t)pos
{
	int val=1;
	for(;;)
	{
		int bit=CSInputNextBit(input);

		if(bit==1) val=contexts[currcontext].oddtable[val];
		else val=contexts[currcontext].eventable[val];

		if(val>=0x100)
		{
			val-=0x100;

			[self updateContextsForByte:val];

			return val;
		}
	}
}

-(void)updateContextsForByte:(int)byte
{
	uint8_t *sometable=contexts[currcontext].sometable;
	uint16_t *eventable=contexts[currcontext].eventable;
	uint16_t *oddtable=contexts[currcontext].oddtable;

	int val=byte+0x100;
	do
	{
		int d5=sometable[val];
		if(d5==1)
		{
			val=d5;
		}
		else
		{
			int d4=sometable[d5];
			int d6=eventable[d4];

			if(d6!=d5)
			{
				eventable[d4]=val;
			}
			else
			{
				d6=oddtable[d4];
				oddtable[d4]=val;
			}

			if(eventable[d5]!=val)
			{
				oddtable[d5]=d6;
			}
			else
			{
				eventable[d5]=d6;
			}

			sometable[val]=d4;
			sometable[d6]=d5;

			val=d4;
		}
	}
	while(val!=1);

	currcontext=byte%numcontexts;
}

@end
