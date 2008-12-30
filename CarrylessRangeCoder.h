#import "CSInputBuffer.h"

typedef struct CarrylessRangeCoder
{
	CSInputBuffer *input;
	uint32_t low,code,range;
} CarrylessRangeCoder;

void InitializeCarrylessRangeCoder(CarrylessRangeCoder *self,CSInputBuffer *input);
int NextSymbolFromCarrylessRangeCoder(CarrylessRangeCoder *self,uint32_t *freqtable,int numfreq);
int NextSymbolFromCarrylessRangeCoderCumulative(CarrylessRangeCoder *self,uint32_t *cumulativetable,int stride);
void NormalizeCarrylessRangeCoder(CarrylessRangeCoder *self);
