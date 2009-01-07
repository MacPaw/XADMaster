#import "PPMdVariantH.h"

uint8_t *pText,*UnitsStart;

static void UpdateModel(PPMdVariantHModel *self);
static PPMdContext *CreateSuccessors(PPMdVariantHModel *self,BOOL skip,PPMdState *p1);

static void DecodeBinSymbolVariantH(PPMdContext *self,PPMdVariantHModel *model);
static void DecodeSymbol1VariantH(PPMdContext *self,PPMdVariantHModel *model);
static void DecodeSymbol2VariantH(PPMdContext *self,PPMdVariantHModel *model);

static void RestartModel(PPMdVariantHModel *self)
{
    memset(self->core.CharMask,0,sizeof(self->core.CharMask));

	InitSubAllocator(&self->core.alloc);

	self->core.PrevSuccess=0;
	self->core.OrderFall=self->MaxOrder;
	self->core.RunLength=self->core.InitRL=-((self->MaxOrder<12)?self->MaxOrder:12)-1;

	self->MaxContext=self->MinContext=NewPPMdContext(&self->core); // AllocContext()
	self->MaxContext->NumStates=256;
	self->MaxContext->SummFreq=257;
	self->MaxContext->States=AllocUnitsRare(&self->core.alloc,256/2);

	PPMdState *maxstates=PPMdContextStates(self->MaxContext,&self->core);
	for(int i=0;i<256;i++)
	{
		maxstates[i].Symbol=i;
		maxstates[i].Freq=1;
		maxstates[i].Successor=0;
	}

	self->core.FoundState=PPMdContextStates(self->MaxContext,&self->core);

	static const uint16_t InitBinEsc[8]={0x3cdd,0x1f3f,0x59bf,0x48f3,0x64a1,0x5abc,0x6632,0x6051};

	for(int i=0;i<128;i++)
	for(int k=0;k<8;k++)
	for(int m=0;m<64;m+=8)
	self->BinSumm[i][k+m]=BIN_SCALE-InitBinEsc[k]/(i+2);

	for(int i=0;i<25;i++)
	for(int k=0;k<16;k++)
	self->SEE2Cont[i][k]=MakeSEE2(5*i+10,4);
}

void StartPPMdVariantHModel(PPMdVariantHModel *self,CSInputBuffer *input,int maxorder)
{
	InitializeRangeCoder(&self->core.coder,input);

	self->core.EscCount=1;
	self->MaxOrder=maxorder;

	RestartModel(self);

	self->NS2BSIndx[0]=2*0;
	self->NS2BSIndx[1]=2*1;
	for(int i=2;i<11;i++) self->NS2BSIndx[i]=2*2;
	for(int i=11;i<256;i++) self->NS2BSIndx[i]=2*3;

	for(int i=0;i<3;i++) self->NS2Indx[i]=i;
	int m=3,k=1,step=1;
	for(int i=3;i<256;i++)
	{
		self->NS2Indx[i]=m;
		if(!--k) { m++; step++; k=step; }
	}

	memset(self->HB2Flag,0,0x40);
	memset(self->HB2Flag+0x40,0x08,0x100-0x40);

	self->DummySEE2Cont.Shift=PERIOD_BITS;
}


int NextPPMdVariantHByte(PPMdVariantHModel *self)
{
	if(self->MinContext->NumStates!=1) DecodeSymbol1VariantH(self->MinContext,self);
	else DecodeBinSymbolVariantH(self->MinContext,self);

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

		DecodeSymbol2VariantH(self->MinContext,self);
		RemoveRangeCoderSubRange(&self->core.coder,self->core.SubRange.LowCount,self->core.SubRange.HighCount);
	}

	uint8_t byte=self->core.FoundState->Symbol;

	if(!self->core.OrderFall&&(uint8_t *)PPMdStateSuccessor(self->core.FoundState,&self->core)>pText)
	self->MinContext=self->MaxContext=PPMdStateSuccessor(self->core.FoundState,&self->core);
	else
	{
		UpdateModel(self);
		if(self->core.EscCount==0) ClearPPMdModelMask(&self->core);
	}

	NormalizeRangeCoderWithBottom(&self->core.coder,1<<15);

	return byte;
}

static void UpdateModel(PPMdVariantHModel *self)
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

	if(self->core.OrderFall==0)
	{
        self->MinContext=self->MaxContext=CreateSuccessors(self,YES,state);
		SetPPMdStateSuccessorPointer(self->core.FoundState,self->MinContext,&self->core);
        if(!self->MinContext) goto RESTART_MODEL;
        return;
		/*if(!MakeRoot(self,2,NULL)) goto RESTART_MODEL;
		self->MinContext=self->MedContext=PPMdStateSuccessor(&fs,&self->core);
		return;*/
	}

	*pText++=fs.Symbol;
	PPMdContext *Successor=(PPMdContext *)pText;

	if(pText>=UnitsStart) goto RESTART_MODEL;

	if(fs.Successor)
	{
		if((uint8_t *)PPMdStateSuccessor(&fs,&self->core)<=pText)
		{
			SetPPMdStateSuccessorPointer(&fs,CreateSuccessors(self,NO,state),&self->core);
			if(!fs.Successor) goto RESTART_MODEL;
		}
		if(--self->core.OrderFall==0)
		{
			Successor=PPMdStateSuccessor(&fs,&self->core);
			if(self->MaxContext!=self->MinContext) pText--;
		}
	}
	else
	{
		SetPPMdStateSuccessorPointer(self->core.FoundState,Successor,&self->core);
		SetPPMdStateSuccessorPointer(&fs,self->MinContext,&self->core);
    }

	int minnum=self->MinContext->NumStates;
	int s0=self->MinContext->SummFreq-minnum-(fs.Freq-1);

	for(PPMdContext *currcontext=self->MaxContext;currcontext!=self->MinContext;currcontext=PPMdContextSuffix(currcontext,&self->core))
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

	self->MaxContext=self->MinContext=PPMdStateSuccessor(&fs,&self->core);

	return;

	RESTART_MODEL:
	RestartModel(self);
	self->core.EscCount=0;
}

static PPMdContext *CreateSuccessors(PPMdVariantHModel *self,BOOL skip,PPMdState *p1)
{
	PPMdContext *pc=self->MinContext,*UpBranch=PPMdStateSuccessor(self->core.FoundState,&self->core);
	PPMdState *p,*ps[MAX_O],**pps=ps;

	if(!skip)
	{
		*pps++=self->core.FoundState;
		if(!pc->Suffix) goto NO_LOOP;
	}

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

	PPMdState UpState;
	if(pps==ps) return pc;

	UpState.Symbol=*(uint8_t *)UpBranch;
	SetPPMdStateSuccessorPointer(&UpState,(PPMdContext *)(((uint8_t *)UpBranch)+1),&self->core);

	if (pc->NumStates!=1)
	{
		if((p=PPMdContextStates(pc,&self->core))->Symbol!=UpState.Symbol)
		do { p++; } while(p->Symbol!=UpState.Symbol);

		unsigned int cf=p->Freq-1;
		unsigned int s0=pc->SummFreq-pc->NumStates-cf;
		UpState.Freq=1+((2*cf<=s0)?(5*cf>s0):((2*cf+3*s0-1)/(2*s0)));
    }
	else UpState.Freq=PPMdContextOneState(pc)->Freq;

	do
	{
		pc=NewPPMdContextAsChildOf(&self->core,pc,*--pps,&UpState);
		if(!pc) return NULL;
	}
	while(pps!=ps);

    return pc;
}




static void DecodeBinSymbolVariantH(PPMdContext *self,PPMdVariantHModel *model)
{
	PPMdState *rs=PPMdContextOneState(self);

	model->HiBitsFlag=model->HB2Flag[model->core.FoundState->Symbol];

	uint16_t *bs=&model->BinSumm[rs->Freq-1][
	model->core.PrevSuccess+model->NS2BSIndx[PPMdContextSuffix(self,&model->core)->NumStates-1]+
	model->HiBitsFlag+2*model->HB2Flag[rs->Symbol]+((model->core.RunLength>>26)&0x20)];

	PPMdDecodeBinSymbol(self,&model->core,bs);
}

static void DecodeSymbol1VariantH(PPMdContext *self,PPMdVariantHModel *model)
{
	int lastsym=PPMdDecodeSymbol1(self,&model->core);
	if(lastsym>=0)
	{
		model->HiBitsFlag=model->HB2Flag[lastsym];
	}
}

static void DecodeSymbol2VariantH(PPMdContext *self,PPMdVariantHModel *model)
{
	int diff=self->NumStates-model->core.NumMasked;
	SEE2Context *see;
	if(self->NumStates!=256)
	{
		see=&model->SEE2Cont[model->NS2Indx[diff-1]][
			+(diff<PPMdContextSuffix(self,&model->core)->NumStates-self->NumStates?1:0)
			+(self->SummFreq<11*self->NumStates?2:0)
			+(model->core.NumMasked>diff?4:0)
			+model->HiBitsFlag];
		model->core.SubRange.scale=GetSEE2Mean(see); // TODO: not masked
	}
	else
	{
		model->core.SubRange.scale=1;
		see=&model->DummySEE2Cont;
	}

	PPMdDecodeSymbol2(self,&model->core,see);
}
