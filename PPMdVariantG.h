#import "PPMdContext.h"

typedef struct PPMdVariantGModel
{
	PPMdCoreModel core;

	PPMdContext *MinContext,*MedContext,*MaxContext;
	int MaxOrder;
	SEE2Context SEE2Cont[43][8],DummySEE2Cont;
	uint8_t NS2BSIndx[256],NS2Indx[256];
	uint16_t BinSumm[128][16]; // binary SEE-contexts
} PPMdVariantGModel;

void StartPPMdVariantGModel(PPMdVariantGModel *self,CSInputBuffer *input);
int NextPPMdVariantGByte(PPMdVariantGModel *self);
