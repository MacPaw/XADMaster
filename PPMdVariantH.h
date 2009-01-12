#import "PPMdContext.h"
#import "PPMdSubAllocatorVariantH.h"

// PPMd Variant H. Used by RAR and 7-Zip.

typedef struct PPMdVariantHModel
{
	PPMdCoreModel core;

	PPMdSubAllocatorVariantH *alloc;

	PPMdContext *MinContext,*MaxContext;
	int MaxOrder,HiBitsFlag;
	SEE2Context SEE2Cont[25][16],DummySEE2Cont;
	uint8_t NS2BSIndx[256],HB2Flag[256],NS2Indx[256];
	uint16_t BinSumm[128][64]; // binary SEE-contexts
} PPMdVariantHModel;

void StartPPMdVariantHModel(PPMdVariantHModel *self,CSInputBuffer *input,int maxorder);
int NextPPMdVariantHByte(PPMdVariantHModel *self);
