#import "CarrylessRangeCoder.h"

void InitializeRangeCoder(CarrylessRangeCoder *self,CSInputBuffer *input)
{
	self->input=input;
	self->low=0;
	self->code=0;
	self->range=0xffffffff;
	for(int i=0;i<4;i++) self->code=(self->code<<8)|CSInputNextByte(input);
}

void InitializeRangeCoderWithTopAndBottom(CarrylessRangeCoder *self,CSInputBuffer *input,uint32_t top,uint32_t bottom)
{
	self->input=input;
	self->low=0;
	self->code=0;
	self->range=0xffffffff;
	for(int i=0;i<4;i++) self->code=(self->code<<8)|CSInputNextByte(input);
}

int NextSymbolFromRangeCoder(CarrylessRangeCoder *self,uint32_t *freqtable,int numfreq)
{
	uint32_t totalfreq=0;
	for(int i=0;i<numfreq;i++) totalfreq+=freqtable[i];

	self->range/=totalfreq;
	uint32_t tmp=(self->code-self->low)/self->range;

	uint32_t cumulativefreq=0;
	uint32_t n=0;
	while(n<numfreq-1&&cumulativefreq+freqtable[n]<=tmp) cumulativefreq+=freqtable[n++];

	self->low+=self->range*cumulativefreq;
	self->range*=freqtable[n];

	NormalizeRangeCoder(self);

	return n;
}

int NextSymbolFromRangeCoderCumulative(CarrylessRangeCoder *self,uint32_t *cumulativetable,int stride)
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

	NormalizeRangeCoder(self);

	return n-1;
}

void NormalizeRangeCoder(CarrylessRangeCoder *self)
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

void NormalizeRangeCoderWithBottom(CarrylessRangeCoder *self,uint32_t bottom)
{
	for(;;)
	{
		if( (self->low^(self->low+self->range))>=0x1000000 )
		{
			if(self->range>=bottom) break;
			else self->range=-self->low&(bottom-1);
		}

		self->code=(self->code<<8) | CSInputNextByte(self->input);
		self->range<<=8;
		self->low<<=8;
	}
}


uint32_t RangeCoderCurrentCount(CarrylessRangeCoder *self,uint32_t scale)
{
	self->range/=scale;
	return (self->code-self->low)/self->range;
}

uint32_t RangeCoderCurrentCountWithShift(CarrylessRangeCoder *self,int shift)
{
	self->range>>=shift;
	return (self->code-self->low)/self->range;
}

void RemoveRangeCoderSubRange(CarrylessRangeCoder *self,uint32_t lowcount,uint32_t highcount)
{
    self->low+=self->range*lowcount;
    self->range*=highcount-lowcount;
}
