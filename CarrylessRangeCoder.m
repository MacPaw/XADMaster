#import "CarrylessRangeCoder.h"

void InitializeCarrylessRangeCoder(CarrylessRangeCoder *self,CSInputBuffer *input)
{
	self->input=input;
	self->low=0;
	self->code=0;
	self->range=0xffffffff;
	for(int i=0;i<4;i++) self->code=(self->code<<8)|CSInputNextByte(input);
}

int NextSymbolFromCarrylessRangeCoder(CarrylessRangeCoder *self,uint32_t *freqtable,int numfreq)
{
	uint32_t totalfreq=0;
	for(int i=0;i<numfreq;i++) totalfreq+=freqtable[i];

	self->range/=totalfreq;
	uint32_t tmp=(self->code-self->low)/self->range;

	uint32_t cumulativefreq=0;
	uint32_t n=0;
	while(n<numfreq-1&&cumulativefreq+freqtable[n]<=tmp)
	{
		cumulativefreq+=freqtable[n++];
	}

	self->low+=self->range*cumulativefreq;
	self->range*=freqtable[n];

	NormalizeCarrylessRangeCoder(self);

	return n;
}

int NextSymbolFromCarrylessRangeCoderCumulative(CarrylessRangeCoder *self,uint32_t *cumulativetable,int stride)
{
	uint32_t totalfreq=*cumulativetable;
	cumulativetable=(uint32_t *)((uint8_t *)cumulativetable+stride);

	self->range/=totalfreq;
	uint32_t tmp=(self->code-self->low)/self->range;

	uint32_t n=0,curr;
	do
	{
		curr=*cumulativetable;
		cumulativetable=(uint32_t *)((uint8_t *)cumulativetable+stride);
		n++;
	} while(tmp<curr);

	cumulativetable=(uint32_t *)((uint8_t *)cumulativetable-2*stride);
	uint32_t prev=*cumulativetable;

	self->low+=self->range*curr;
	self->range*=prev-curr;

	NormalizeCarrylessRangeCoder(self);

	return n-1;
}

void NormalizeCarrylessRangeCoder(CarrylessRangeCoder *self)
{
	for(;;)
	{
		if( (self->low^(self->low+self->range))>=0x1000000 )
		{
//NSLog(@"a");
			if(self->range>=0x10000) break;
			else self->range=-self->low&0xffff;
//NSLog(@"b");
		}
//NSLog(@"loop %x %x %x",self->low,self->code,self->range);

		self->code=(self->code<<8) | CSInputNextByte(self->input);
		self->range<<=8;
		self->low<<=8;
	}
}
