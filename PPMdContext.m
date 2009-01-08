#import "PPMdContext.h"

SEE2Context MakeSEE2(int initval,int count)
{
	SEE2Context self;
	self.Shift=PERIOD_BITS-4;
	self.Summ=initval<<self.Shift;
	self.Count=count;
	return self;
}

unsigned int GetSEE2MeanMasked(SEE2Context *self)
{
	unsigned int retval=self->Summ>>self->Shift;
	self->Summ-=retval;
	retval&=0x03ff;
	if(retval==0) return 1;
	return retval;
}

unsigned int GetSEE2Mean(SEE2Context *self)
{
	unsigned int retval=self->Summ>>self->Shift;
	self->Summ-=retval;
	if(retval==0) return 1;
	return retval;
}

void UpdateSEE2(SEE2Context *self)
{
	if(self->Shift>=PERIOD_BITS) return;

	self->Count--;
	if(self->Count==0)
	{
		self->Summ*=2;
		self->Count=3<<self->Shift;
		self->Shift++;
	}
}




PPMdContext *PPMdStateSuccessor(PPMdState *self,PPMdCoreModel *model)
{ return OffsetToPointer(model->alloc,self->Successor); }

void SetPPMdStateSuccessorPointer(PPMdState *self,PPMdContext *newsuccessor,PPMdCoreModel *model)
{ self->Successor=PointerToOffset(model->alloc,newsuccessor); }

PPMdState *PPMdContextStates(PPMdContext *self,PPMdCoreModel *model)
{ return OffsetToPointer(model->alloc,self->States); }

void SetPPMdContextStatesPointer(PPMdContext *self, PPMdState *newstates,PPMdCoreModel *model)
{ self->States=PointerToOffset(model->alloc,newstates); }

PPMdContext *PPMdContextSuffix(PPMdContext *self,PPMdCoreModel *model)
{ return OffsetToPointer(model->alloc,self->Suffix); } 

void SetPPMdContextSuffixPointer(PPMdContext *self,PPMdContext *newsuffix,PPMdCoreModel *model)
{ self->Suffix=PointerToOffset(model->alloc,newsuffix); }

PPMdState *PPMdContextOneState(PPMdContext *self) { return (PPMdState *)&self->SummFreq; }

PPMdContext *NewPPMdContext(PPMdCoreModel *model)
{
	PPMdContext *context=OffsetToPointer(model->alloc,AllocContext(model->alloc));
	if(context)
	{
		context->NumStates=0;
		context->Suffix=0;
	}
	return context;
}

PPMdContext *NewPPMdContextAsChildOf(PPMdCoreModel *model,PPMdContext *suffixcontext,PPMdState *suffixstate,PPMdState *firststate)
{
	PPMdContext *context=OffsetToPointer(model->alloc,AllocContext(model->alloc));
	if(context)
	{
		context->NumStates=1;
		SetPPMdContextSuffixPointer(context,suffixcontext,model);
		SetPPMdStateSuccessorPointer(suffixstate,context,model);
		*(PPMdContextOneState(context))=*firststate;
	}
	return context;
}



// Tabulated escapes for exponential symbol distribution
static const uint8_t ExpEscape[16]={ 25,14,9,7,5,5,4,4,4,3,3,3,2,2,2,2 };

#define GET_MEAN(SUMM,SHIFT,ROUND) ((SUMM+(1<<(SHIFT-ROUND)))>>(SHIFT))

void PPMdDecodeBinSymbol(PPMdContext *self,PPMdCoreModel *model,uint16_t *bs)
{
	PPMdState *rs=PPMdContextOneState(self);
	if(RangeCoderCurrentCountWithShift(&model->coder,TOT_BITS)<*bs)
	{
		model->SubRange.LowCount=0;
		model->SubRange.HighCount=*bs;
		model->PrevSuccess=1;
		model->RunLength++;
		model->FoundState=rs;

		if(rs->Freq<128) rs->Freq++;
		*bs+=INTERVAL-GET_MEAN(*bs,PERIOD_BITS,2);
	}
	else
	{
		model->SubRange.LowCount=*bs;
		model->SubRange.HighCount=BIN_SCALE;
		model->PrevSuccess=0;
		model->FoundState=NULL;
		model->NumMasked=1;
		model->CharMask[rs->Symbol]=model->EscCount;

		*bs-=GET_MEAN(*bs,PERIOD_BITS,2);
		model->InitEsc=ExpEscape[*bs>>10];
	}
}

int PPMdDecodeSymbol1(PPMdContext *self,PPMdCoreModel *model)
{
	model->SubRange.scale=self->SummFreq;

	PPMdState *states=PPMdContextStates(self,model);
	int firstcount=states[0].Freq;
	int count=RangeCoderCurrentCount(&model->coder,model->SubRange.scale);

	if(count<firstcount)
	{
		model->SubRange.HighCount=firstcount;
		if(2*firstcount>model->SubRange.scale)
		{
			model->PrevSuccess=1;
			model->RunLength++;
		}
		else model->PrevSuccess=0;

		model->FoundState=&states[0];
		states[0].Freq=firstcount+4;
		self->SummFreq+=4;

		if(firstcount+4>MAX_FREQ) RescalePPMdContext(self,model);
		model->SubRange.LowCount=0;

		return -1;
	}

	int highcount=firstcount;
	model->PrevSuccess=0;

	for(int i=1;i<self->NumStates;i++)
	{
		highcount+=states[i].Freq;
		if(highcount>count)
		{
			model->SubRange.LowCount=highcount-states[i].Freq;
			model->SubRange.HighCount=highcount;
			UpdatePPMdContext1(self,model,&states[i]);
			return -1;
		}
	}

	int lastsym=model->FoundState->Symbol;

	model->SubRange.LowCount=highcount;
	model->SubRange.HighCount=model->SubRange.scale;
	model->NumMasked=self->NumStates;
	model->FoundState=NULL;

	for(int i=0;i<self->NumStates;i++) model->CharMask[states[i].Symbol]=model->EscCount;

	return lastsym;
}

void UpdatePPMdContext1(PPMdContext *self,PPMdCoreModel *model,PPMdState *state)
{
	state->Freq+=4;
	self->SummFreq+=4;

	if(state[0].Freq>state[-1].Freq)
	{
		SWAP(state[0],state[-1]);
		model->FoundState=&state[-1];
		if(state[-1].Freq>MAX_FREQ) RescalePPMdContext(self,model);
	}
	else
	{
		model->FoundState=state;
	}
}



void PPMdDecodeSymbol2(PPMdContext *self,PPMdCoreModel *model,SEE2Context *see)
{
	int n=self->NumStates-model->NumMasked;
	PPMdState *ps[256];

	int total=0;
	PPMdState *state=PPMdContextStates(self,model);
	for(int i=0;i<n;i++)
	{
		while(model->CharMask[state->Symbol]==model->EscCount) state++;

		total+=state->Freq;
		ps[i]=state++;
	}

	model->SubRange.scale+=total;
	int count=RangeCoderCurrentCount(&model->coder,model->SubRange.scale);

	if(count<total)
	{
		int i=0,highcount=ps[0]->Freq;
		while(highcount<=count) highcount+=ps[++i]->Freq;

		model->SubRange.LowCount=highcount-ps[i]->Freq;
		model->SubRange.HighCount=highcount;
		UpdateSEE2(see);
		UpdatePPMdContext2(self,model,ps[i]);
	}
	else
	{
		model->SubRange.LowCount=total;
		model->SubRange.HighCount=model->SubRange.scale;
		model->NumMasked=self->NumStates;
		see->Summ+=model->SubRange.scale;

		for(int i=0;i<n;i++) model->CharMask[ps[i]->Symbol]=model->EscCount;
	}
}

void UpdatePPMdContext2(PPMdContext *self,PPMdCoreModel *model,PPMdState *state)
{
	model->FoundState=state;
	state->Freq+=4;
	self->SummFreq+=4;
	if(state->Freq>MAX_FREQ) RescalePPMdContext(self,model);
	model->EscCount++;
	model->RunLength=model->InitRL;
}

void RescalePPMdContext(PPMdContext *self,PPMdCoreModel *model)
{
	PPMdState *states=PPMdContextStates(self,model);
	int n=self->NumStates;

	// Bump frequency of found state
	model->FoundState->Freq+=4;

	// Divide all frequencies and sort list
	int escfreq=self->SummFreq+4;
	int adder=(model->OrderFall==0?0:1);
	self->SummFreq=0;

	for(int i=0;i<n;i++)
	{
		escfreq-=states[i].Freq;
		states[i].Freq=(states[i].Freq+adder)>>1;
		self->SummFreq+=states[i].Freq;

		// Keep states sorted by decreasing frequency
		if(i>0&&states[i].Freq>states[i-1].Freq)
		{
			// If not sorted, move current state upwards until list is sorted
			PPMdState tmp=states[i];

			int j=i-1;
			while(j>0&&tmp.Freq>states[j-1].Freq) j--;

			memmove(&states[j+1],&states[j],sizeof(PPMdState)*(i-j));
			states[j]=tmp;
		}
	}

	// TODO: add better sorting stage here.

	// Drop states whose frequency has fallen to 0
	if(states[n-1].Freq==0)
	{
		int numzeros=1;
		while(numzeros<n&&states[n-1-numzeros].Freq==0) numzeros++;

		escfreq+=numzeros;

		self->NumStates-=numzeros;
		if(self->NumStates==1)
		{
			PPMdState tmp=states[0];
			do
			{
				tmp.Freq=(tmp.Freq+1)>>1;
				escfreq>>=1;
			}
			while(escfreq>1);

			FreeUnits(model->alloc,self->States,(n+1)>>1);
			model->FoundState=PPMdContextOneState(self);
			*model->FoundState=tmp;

			return;
		}

		int n0=(n+1)>>1,n1=(self->NumStates+1)>>1;
		if(n0!=n1) self->States=ShrinkUnits(model->alloc,self->States,n0,n1);
	}

	self->SummFreq+=(escfreq+1)>>1;

	// The found state is the first one to breach the limit, thus it is the largest and also first
	model->FoundState=PPMdContextStates(self,model);
}




void ClearPPMdModelMask(PPMdCoreModel *self)
{
	self->EscCount=1;
	memset(self->CharMask,0,sizeof(self->CharMask));
}
