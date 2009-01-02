#import "CSByteStreamHandle.h"
#import "PPMSubAllocator.h"

typedef struct SEE2Context
{ // SEE-contexts for PPM-contexts with masked symbols
	uint16_t Summ;
	uint8_t Shift,Count;
}  __attribute__((__packed__)) SEE2Context;

typedef struct PPMSubRange {
    uint32_t LowCount,HighCount,scale;
} PPMSubRange;

typedef struct PPMContext PPMContext;

typedef struct PPMState { uint8_t Symbol,Freq; PPMContext *Successor; } __attribute__((__packed__)) PPMState;

struct PPMContext
{
	uint16_t NumStats,SummFreq;
	PPMState *Stats;
    PPMContext *Suffix;
} __attribute__((__packed__));


@interface XADPPMdVariantGHandle:CSByteStreamHandle
{
	PPMSubRange SubRange;
	uint32_t low,code,range;

	PPMSubAllocator alloc;

	SEE2Context SEE2Cont[44][8];
	PPMContext *MinContext,*MedContext,*MaxContext;
	PPMState *FoundState; // found next state transition
	int NumMasked,InitEsc,OrderFall,MaxOrder;
	uint8_t CharMask[256],NS2Indx[256],NS2BSIndx[256];
	uint8_t EscCount,PrintCount,PrevSuccess;
	//int EscCount,PrintCount,PrevSuccess;
	uint16_t BinSumm[128][16]; // binary SEE-contexts
}

-(id)initWithHandle:(CSHandle *)handle maxOrder:(int)maxorder subAllocSize:(int)suballocsize;
-(id)initWithHandle:(CSHandle *)handle length:(off_t)length maxOrder:(int)maxorder subAllocSize:(int)suballocsize;
-(void)dealloc;

-(void)resetByteStream;
-(uint8_t)produceByteAtOffset:(off_t)pos;

@end

typedef XADPPMdVariantGHandle PPMModel;
