#import "PPMSubAllocator.h"
#import "CarrylessRangeCoder.h"

typedef struct SEE2Context
{ // SEE-contexts for PPM-contexts with masked symbols
	uint16_t Summ;
	uint8_t Shift,Count;
}  __attribute__((__packed__)) SEE2Context;

typedef struct PPMContext PPMContext;

typedef struct PPMState { uint8_t Symbol,Freq; PPMContext *Successor; } __attribute__((__packed__)) PPMState;

struct PPMContext
{
	uint16_t NumStates,SummFreq;
	PPMState *States;
    PPMContext *Suffix;
} __attribute__((__packed__));

typedef struct PPMdVariantGModel
{
	PPMSubAllocator alloc;

	CarrylessRangeCoder coder;
	struct { uint32_t LowCount,HighCount,scale; } SubRange;

	SEE2Context SEE2Cont[43][8],DummySEE2Cont;
	PPMContext *MinContext,*MedContext,*MaxContext;
	PPMState *FoundState; // found next state transition
	int NumMasked,InitEsc,OrderFall,MaxOrder;
	uint8_t CharMask[256],NS2Indx[256],NS2BSIndx[256];
	uint8_t EscCount,PrintCount,PrevSuccess;
	//int EscCount,PrintCount,PrevSuccess;
	uint16_t BinSumm[128][16]; // binary SEE-contexts
} PPMdVariantGModel;

void StartPPMdVariantGModel(PPMdVariantGModel *self,CSInputBuffer *input);
int NextPPMdVariantGByte(PPMdVariantGModel *self);
