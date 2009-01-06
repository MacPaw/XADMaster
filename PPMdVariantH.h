#import "PPMSubAllocator.h"
#import "CarrylessRangeCoder.h"

typedef struct SEE2Context
{ // SEE-contexts for PPM-contexts with masked symbols
	uint16_t Summ;
	uint8_t Shift,Count;
}  __attribute__((__packed__)) SEE2Context;

typedef struct PPMContext PPMContext;

typedef struct PPMState { uint8_t Symbol,Freq; uint32_t Successor; } __attribute__((__packed__)) PPMState;

struct PPMContext
{
	uint16_t NumStates,SummFreq;
	uint32_t States;
    uint32_t Suffix;
} __attribute__((__packed__));

typedef struct PPMdVariantHModel
{
	PPMSubAllocator alloc;

	CarrylessRangeCoder coder;
	struct { uint32_t LowCount,HighCount,scale; } SubRange;

	SEE2Context SEE2Cont[25][16],DummySEE2Cont;
	PPMContext *MinContext,*MedContext,*MaxContext;
	PPMState *FoundState; // found next state transition
	int NumMasked,InitEsc,OrderFall,RunLength,InitRL,MaxOrder;
	uint8_t CharMask[256],NS2Indx[256],NS2BSIndx[256],HB2Flag[256];
	uint8_t EscCount,PrintCount,PrevSuccess,HiBitsFlag;
	uint16_t BinSumm[128][64]; // binary SEE-contexts
} PPMdVariantHModel;

void StartPPMdVariantHModel(PPMdVariantHModel *self,CSInputBuffer *input);
int NextPPMdVariantHByte(PPMdVariantHModel *self);
