#import "CSInputBuffer.h"

typedef struct CarrylessRangeCoder
{
	CSInputBuffer *input;
	uint32_t low,code,range;
} CarrylessRangeCoder;

void InitializeRangeCoder(CarrylessRangeCoder *self,CSInputBuffer *input);

int NextSymbolFromRangeCoder(CarrylessRangeCoder *self,uint32_t *freqtable,int numfreq);

int NextSymbolFromRangeCoderWithoutLow(CarrylessRangeCoder *self,uint32_t *freqtable,int numfreq);
int NextBitFromRangeCoderWithoutLow(CarrylessRangeCoder *self);
int NextWeightedBitFromRangeCoderWithoutLow(CarrylessRangeCoder *self,int weight,int shift);
int NextWeightedBitFromRangeCoderWithoutLow2(CarrylessRangeCoder *self,int weight,int size);

void NormalizeRangeCoder(CarrylessRangeCoder *self);
void NormalizeRangeCoderWithBottom(CarrylessRangeCoder *self,uint32_t bottom);

uint32_t RangeCoderCurrentCount(CarrylessRangeCoder *self,uint32_t scale);
uint32_t RangeCoderCurrentCountWithShift(CarrylessRangeCoder *self,int shift);
void RemoveRangeCoderSubRange(CarrylessRangeCoder *self,uint32_t lowcount,uint32_t highcount);
