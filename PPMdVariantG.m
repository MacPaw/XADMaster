#import "PPMdVariantG.h"

static void UpdateModel(PPMdVariantGModel *self);
static BOOL MakeRoot(PPMdVariantGModel *self,unsigned int SkipCount,PPMdState *p1);

static void DecodeBinSymbolVariantG(PPMdContext *self,PPMdVariantGModel *model);
static void DecodeSymbol1VariantG(PPMdContext *self,PPMdVariantGModel *model);
static void DecodeSymbol2VariantG(PPMdContext *self,PPMdVariantGModel *model);

void StartPPMdVariantGModel(PPMdVariantGModel *self,CSInputBuffer *input)
{
	BOOL brimstone=NO;

	if(input) InitializeRangeCoder(&self->core.coder,input);

	InitSubAllocator(&self->core.alloc);

	self->core.PrevSuccess=0;
	self->core.OrderFall=1;

	self->MaxContext=NewPPMdContext(&self->core);
	self->MaxContext->NumStates=256;
	self->MaxContext->SummFreq=257;
	self->MaxContext->States=AllocUnitsRare(&self->core.alloc,256/2);

	PPMdState *maxstates=PPMdContextStates(self->MaxContext,&self->core);
	for(int i=0;i<256;i++)
	{
		maxstates[i].Symbol=i;
		if(brimstone) maxstates[i].Freq=i<0x80?2:1;
		else maxstates[i].Freq=1;
		maxstates[i].Successor=0;
	}

	PPMdState *state=maxstates;
	for(int i=1;;i++)
	{
		PPMdState firststate={0,1};
		self->MaxContext=NewPPMdContextAsChildOf(&self->core,self->MaxContext,state,&firststate);
		if(i==self->MaxOrder) break;
		//state=ContextOneState(self->MaxContext);
		//state->Symbol=0;
		//state->Freq=1;
	}

	self->MaxContext->NumStates=0;
	self->MedContext=self->MinContext=PPMdContextSuffix(self->MaxContext,&self->core);

	static const uint16_t InitBinEsc[16]=
	{
		0x3CDD,0x1F3F,0x59BF,0x48F3,0x5FFB,0x5545,0x63D1,0x5D9D,
		0x64A1,0x5ABC,0x6632,0x6051,0x68F6,0x549B,0x6BCA,0x3AB0,
	};

	for(int i=0;i<128;i++)
	for(int k=0;k<16;k++)
	self->BinSumm[i][k]=BIN_SCALE-InitBinEsc[k]/(i+2);

	for(int i=0;i<6;i++) self->NS2BSIndx[i]=2*i;
	for(int i=6;i<50;i++) self->NS2BSIndx[i]=12;
	for(int i=50;i<256;i++) self->NS2BSIndx[i]=14;

	for(int i=0;i<43;i++)
	for(int k=0;k<8;k++)
	self->SEE2Cont[i][k]=MakeSEE2(4*i+10,3);

	self->DummySEE2Cont.Shift=PERIOD_BITS;

	for(int i=0;i<4;i++) self->NS2Indx[i]=i;
	for(int i=4;i<4+8;i++) self->NS2Indx[i]=4+((i-4)>>1);
	for(int i=4+8;i<4+8+32;i++) self->NS2Indx[i]=4+4+((i-4-8)>>2);
	for(int i=4+8+32;i<256;i++) self->NS2Indx[i]=4+4+8+((i-4-8-32)>>3);

	memset(self->core.CharMask,0,sizeof(self->core.CharMask));
	self->core.EscCount=1;
}

int NextPPMdVariantGByte(PPMdVariantGModel *self)
{
	if(self->MinContext->NumStates!=1) DecodeSymbol1VariantG(self->MinContext,self);
	else DecodeBinSymbolVariantG(self->MinContext,self);

	RemoveRangeCoderSubRange(&self->core.coder,self->core.SubRange.LowCount,self->core.SubRange.HighCount);

	while(!self->core.FoundState)
	{
		NormalizeRangeCoderWithBottom(&self->core.coder,1<<15);
		do
		{
			self->core.OrderFall++;
			self->MinContext=PPMdContextSuffix(self->MinContext,&self->core);
			if(!self->MinContext) return -1;
		}
		while(self->MinContext->NumStates==self->core.NumMasked);

		DecodeSymbol2VariantG(self->MinContext,self);
		RemoveRangeCoderSubRange(&self->core.coder,self->core.SubRange.LowCount,self->core.SubRange.HighCount);
	}

	uint8_t byte=self->core.FoundState->Symbol;

	if(!self->core.OrderFall&&PPMdStateSuccessor(self->core.FoundState,&self->core)->NumStates)
	self->MinContext=self->MedContext=PPMdStateSuccessor(self->core.FoundState,&self->core);
	else
	{
		UpdateModel(self);
		if(self->core.EscCount==0) ClearPPMdModelMask(&self->core);
	}

	NormalizeRangeCoderWithBottom(&self->core.coder,1<<15);

	return byte;
}



static void UpdateModel(PPMdVariantGModel *self)
{
	PPMdState fs=*self->core.FoundState;
	PPMdState *state=NULL;

	if(fs.Freq<MAX_FREQ/4&&self->MinContext->Suffix)
	{
		PPMdContext *context=PPMdContextSuffix(self->MinContext,&self->core);
		if(context->NumStates!=1)
		{
			state=PPMdContextStates(context,&self->core);

			if(state->Symbol!=fs.Symbol)
			{
				do state++;
				while(state->Symbol!=fs.Symbol);

				if(state[0].Freq>=state[-1].Freq)
				{
					SWAP(state[0],state[-1]);
					state--;
				}
			}

			if(state->Freq<7*MAX_FREQ/8)
			{
				state->Freq+=2;
				context->SummFreq+=2;
			}
		}
		else
		{
			state=PPMdContextOneState(context);
			if(state->Freq<32) state->Freq++;
		}
	}

	PPMdContext *Successor;
	int SkipCount=0;
	if(self->core.OrderFall==0)
	{
		if(!MakeRoot(self,2,NULL)) goto RESTART_MODEL;
		self->MinContext=self->MedContext=PPMdStateSuccessor(&fs,&self->core);
		return;
	}
	else if(--self->core.OrderFall==0)
	{
		Successor=PPMdStateSuccessor(&fs,&self->core);
		SkipCount=1;
	}
	else
	{
		Successor=NewPPMdContext(&self->core);
		if(!Successor) goto RESTART_MODEL;
	}

	if(!self->MaxContext->NumStates)
	{
		PPMdContextOneState(self->MaxContext)->Symbol=fs.Symbol;
		SetPPMdStateSuccessorPointer(PPMdContextOneState(self->MaxContext),Successor,&self->core);
	}

	int minnum=self->MinContext->NumStates;
	int s0=self->MinContext->SummFreq-minnum-(fs.Freq-1);

	for(PPMdContext *currcontext=self->MedContext;currcontext!=self->MinContext;currcontext=PPMdContextSuffix(currcontext,&self->core))
	{
		int currnum=currcontext->NumStates;
		if(currnum!=1)
		{
			if((currnum&1)==0)
			{
				currcontext->States=ExpandUnits(&self->core.alloc,currcontext->States,currnum>>1);
				if(!currcontext->States) goto RESTART_MODEL;
			}
			if(4*currnum<=minnum&&currcontext->SummFreq<=8*currnum) currcontext->SummFreq+=2;
			if(2*currnum<minnum) currcontext->SummFreq++;
		}
		else
		{
			PPMdState *states=OffsetToPointer(&self->core.alloc,AllocUnitsRare(&self->core.alloc,1));
			if(!states) goto RESTART_MODEL;
			states[0]=*(PPMdContextOneState(currcontext));
			SetPPMdContextStatesPointer(currcontext,states,&self->core);

			if(states[0].Freq<MAX_FREQ/4-1) states[0].Freq*=2;
			else states[0].Freq=MAX_FREQ-4;

			currcontext->SummFreq=states[0].Freq+self->core.InitEsc+(minnum>3?1:0);
		}

		unsigned int cf=2*fs.Freq*(currcontext->SummFreq+6);
		unsigned int sf=s0+currcontext->SummFreq;
		unsigned int freq;

		if(cf<6*sf)
		{
			if(cf>=4*sf) freq=3;
			else if(cf>sf) freq=2;
			else freq=1;
			currcontext->SummFreq+=3;
		}
		else
		{
			if(cf>=15*sf) freq=7;
			else if(cf>=12*sf) freq=6;
			else if(cf>=9*sf) freq=5;
			else freq=4;
			currcontext->SummFreq+=freq;
		}

		PPMdState *currstates=PPMdContextStates(currcontext,&self->core);
		PPMdState *new=&currstates[currnum];
		SetPPMdStateSuccessorPointer(new,Successor,&self->core);
		new->Symbol=fs.Symbol;
		new->Freq=freq;
		currcontext->NumStates=currnum+1;
	}

	if(fs.Successor)
	{
		if(!PPMdStateSuccessor(&fs,&self->core)->NumStates&&!MakeRoot(self,SkipCount,state)) goto RESTART_MODEL;
		self->MinContext=PPMdStateSuccessor(self->core.FoundState,&self->core);
	}
	else
	{
		SetPPMdStateSuccessorPointer(self->core.FoundState,Successor,&self->core);
		self->core.OrderFall++;
	}

	self->MedContext=self->MinContext;
	self->MaxContext=Successor;
	return;

	RESTART_MODEL:
	StartPPMdVariantGModel(self,NULL);
	self->core.EscCount=0;
}

static BOOL MakeRoot(PPMdVariantGModel *self,unsigned int SkipCount,PPMdState *p1)
{
	PPMdContext *pc=self->MinContext,*UpBranch=PPMdStateSuccessor(self->core.FoundState,&self->core);
	PPMdState *p,*ps[MAX_O],**pps=ps;

	if(SkipCount==0)
	{
		*pps++=self->core.FoundState;
		if(!pc->Suffix) goto NO_LOOP;
	}
	else if(SkipCount==2) pc=PPMdContextSuffix(pc,&self->core);

	if(p1)
	{
		p=p1;
		pc=PPMdContextSuffix(pc,&self->core);
		goto LOOP_ENTRY;
	}

	do
	{
		pc=PPMdContextSuffix(pc,&self->core);
		if(pc->NumStates!=1)
		{
			if((p=PPMdContextStates(pc,&self->core))->Symbol!=self->core.FoundState->Symbol)
			{
				do p++;
				while(p->Symbol!=self->core.FoundState->Symbol);
			}
		}
		else p=PPMdContextOneState(pc);

		LOOP_ENTRY:
		if(PPMdStateSuccessor(p,&self->core)!=UpBranch)
		{
			pc=PPMdStateSuccessor(p,&self->core);
			break;
		}
		*pps++=p;
	}
	while(pc->Suffix);

	NO_LOOP: 0;
	PPMdState *UpState=PPMdContextOneState(UpBranch);
	if(pc->NumStates!=1)
	{
		unsigned int cf=UpState->Symbol;
		p=PPMdContextStates(pc,&self->core);
		while(p->Symbol!=cf) p++;

		unsigned int s0=pc->SummFreq-pc->NumStates-(cf=p->Freq-1);
		UpState->Freq=1+((2*cf<=s0)?(5*cf>s0):((2*cf+3*s0-1)/(2*s0)));
	}
	else UpState->Freq=PPMdContextOneState(pc)->Freq;

	while(--pps>=ps)
	{
		pc=NewPPMdContextAsChildOf(&self->core,pc,*pps,UpState);
		if(!pc) return FALSE;
	}

	if(!self->core.OrderFall)
	{
		UpBranch->NumStates=1;
		SetPPMdContextSuffixPointer(UpBranch,pc,&self->core);
	}

	return TRUE;
}




static void DecodeBinSymbolVariantG(PPMdContext *self,PPMdVariantGModel *model)
{
	PPMdState *rs=PPMdContextOneState(self);
	uint16_t *bs=&model->BinSumm[rs->Freq-1][model->core.PrevSuccess+model->NS2BSIndx[PPMdContextSuffix(self,&model->core)->NumStates-1]];

	PPMdDecodeBinSymbol(self,&model->core,bs);
}

static void DecodeSymbol1VariantG(PPMdContext *self,PPMdVariantGModel *model)
{
	PPMdDecodeSymbol1(self,&model->core);
}


static void DecodeSymbol2VariantG(PPMdContext *self,PPMdVariantGModel *model)
{
	int diff=self->NumStates-model->core.NumMasked;
	SEE2Context *see;
	if(self->NumStates!=256)
	{
		see=&model->SEE2Cont[model->NS2Indx[diff-1]][
			+(diff<PPMdContextSuffix(self,&model->core)->NumStates-self->NumStates?1:0)
			+(self->SummFreq<11*self->NumStates?2:0)
			+(model->core.NumMasked>diff?4:0)];
		model->core.SubRange.scale=GetSEE2Mean(see);
	}
	else
	{
		model->core.SubRange.scale=1;
		see=&model->DummySEE2Cont;
	}

	PPMdDecodeSymbol2(self,&model->core,see);
}
