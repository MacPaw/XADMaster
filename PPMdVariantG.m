#import "PPMdVariantG.h"

#define MAX_O 16
#define INT_BITS 7
#define PERIOD_BITS 7
#define MAX_FREQ 124
#define INTERVAL (1<<INT_BITS)
#define BIN_SCALE (INTERVAL<<PERIOD_BITS)

#define SWAP(t1,t2) { PPMState tmp=(t1); (t1)=(t2); (t2)=tmp; }

static void UpdateModel(PPMdVariantGModel *self);
static BOOL MakeRoot(PPMdVariantGModel *self,unsigned int SkipCount,PPMState *p1);
static void ClearMask(PPMdVariantGModel *self);

static SEE2Context MakeSEE2(int initval);
static unsigned int GetSEE2Mean(SEE2Context *self);
static void UpdateSEE2(SEE2Context *self);

static PPMContext *StateSuccessor(PPMState *self,PPMdVariantGModel *model);
static void SetStateSuccessorPointer(PPMState *self,PPMContext *newsuccessor,PPMdVariantGModel *model);
static PPMState *ContextStates(PPMContext *self,PPMdVariantGModel *model);
static void SetContextStatesPointer(PPMContext *self, PPMState *newstates,PPMdVariantGModel *model);
static PPMContext *ContextSuffix(PPMContext *self,PPMdVariantGModel *model);
static void SetContextSuffixPointer(PPMContext *self,PPMContext *newsuffix,PPMdVariantGModel *model);
static PPMState *ContextOneState(PPMContext *self);

static void InitPPMContext(PPMContext *self);
static void InitPPMContextWithContext(PPMContext *self,PPMState *pstats,PPMContext *shortercontext,PPMdVariantGModel *model);
static PPMContext *NewPPMContext(PPMdVariantGModel *model);
static PPMContext *NewPPMContextWithContext(PPMdVariantGModel *model,PPMState *pstats,PPMContext *shortercontext);

static void DecodeBinSymbol(PPMContext *self,PPMdVariantGModel *model);
static void DecodeSymbol1(PPMContext *self,PPMdVariantGModel *model);
static void UpdateContext1(PPMContext *self,PPMdVariantGModel *model,PPMState *state);
static void DecodeSymbol2(PPMContext *self,PPMdVariantGModel *model);
static SEE2Context *MakeEscFreq2(PPMContext *self,PPMdVariantGModel *model,int Diff);
static void UpdateContext2(PPMContext *self,PPMdVariantGModel *model,PPMState *state);
static void RescaleContext(PPMContext *self,PPMdVariantGModel *model);

void StartPPMdVariantGModel(PPMdVariantGModel *self,CSInputBuffer *input)
{
	BOOL brimstone=NO;

	if(input) InitializeRangeCoder(&self->coder,input);

	InitSubAllocator(&self->alloc);

	self->PrevSuccess=0;
	self->OrderFall=1;

	self->MaxContext=NewPPMContext(self);
	self->MaxContext->Suffix=0;
	self->MaxContext->NumStates=256;
	self->MaxContext->SummFreq=257;
	self->MaxContext->States=AllocUnitsRare(&self->alloc,256/2);

	PPMState *maxstates=ContextStates(self->MaxContext,self);
	for(int i=0;i<256;i++)
	{
		maxstates[i].Symbol=i;
		if(brimstone) maxstates[i].Freq=i<0x80?2:1;
		else maxstates[i].Freq=1;
		maxstates[i].Successor=0;
	}

	PPMState *state=maxstates;
	for(int i=1;;i++)
	{
		self->MaxContext=NewPPMContextWithContext(self,state,self->MaxContext);
		if(i==self->MaxOrder) break;
		state=ContextOneState(self->MaxContext);
		state->Symbol=0;
		state->Freq=1;
	}

	self->MaxContext->NumStates=0;
	self->MedContext=self->MinContext=ContextSuffix(self->MaxContext,self);

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
	self->SEE2Cont[i][k]=MakeSEE2(4*i+10);

	self->DummySEE2Cont.Shift=PERIOD_BITS;

	for(int i=0;i<4;i++) self->NS2Indx[i]=i;
	for(int i=4;i<4+8;i++) self->NS2Indx[i]=4+((i-4)>>1);
	for(int i=4+8;i<4+8+32;i++) self->NS2Indx[i]=4+4+((i-4-8)>>2);
	for(int i=4+8+32;i<256;i++) self->NS2Indx[i]=4+4+8+((i-4-8-32)>>3);

	memset(self->CharMask,0,sizeof(self->CharMask));
	self->EscCount=1;
}

int NextPPMdVariantGByte(PPMdVariantGModel *self)
{
	if(self->MinContext->NumStates!=1) DecodeSymbol1(self->MinContext,self);
	else DecodeBinSymbol(self->MinContext,self);

	RemoveRangeCoderSubRange(&self->coder,self->SubRange.LowCount,self->SubRange.HighCount);

	while(!self->FoundState)
	{
		NormalizeRangeCoderWithBottom(&self->coder,1<<15);
		do
		{
			self->OrderFall++;
			self->MinContext=ContextSuffix(self->MinContext,self);
			if(!self->MinContext) return -1;
		}
		while(self->MinContext->NumStates==self->NumMasked);

		DecodeSymbol2(self->MinContext,self);
		RemoveRangeCoderSubRange(&self->coder,self->SubRange.LowCount,self->SubRange.HighCount);
	}

	uint8_t byte=self->FoundState->Symbol;

	if(!self->OrderFall&&StateSuccessor(self->FoundState,self)->NumStates)
	self->MinContext=self->MedContext=StateSuccessor(self->FoundState,self);
	else
	{
		UpdateModel(self);
		if(self->EscCount==0) ClearMask(self);
	}

	NormalizeRangeCoderWithBottom(&self->coder,1<<15);

	return byte;
}



static void UpdateModel(PPMdVariantGModel *self)
{
	PPMState fs=*self->FoundState;
	PPMState *state=NULL;

	if(fs.Freq<MAX_FREQ/4&&self->MinContext->Suffix)
	{
		PPMContext *context=ContextSuffix(self->MinContext,self);
		if(context->NumStates!=1)
		{
			state=ContextStates(context,self);

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
			state=ContextOneState(context);
			if(state->Freq<32) state->Freq++;
		}
	}

	PPMContext *Successor;
	int SkipCount=0;
	if(self->OrderFall==0)
	{
		if(!MakeRoot(self,2,NULL)) goto RESTART_MODEL;
		self->MinContext=self->MedContext=StateSuccessor(&fs,self);
		return;
	}
	else if(--self->OrderFall==0)
	{
		Successor=StateSuccessor(&fs,self);
		SkipCount=1;
	}
	else
	{
		Successor=NewPPMContext(self);
		if(!Successor) goto RESTART_MODEL;
	}

	if(!self->MaxContext->NumStates)
	{
		ContextOneState(self->MaxContext)->Symbol=fs.Symbol;
		SetStateSuccessorPointer(ContextOneState(self->MaxContext),Successor,self);
	}

	int minnum=self->MinContext->NumStates;
	int s0=self->MinContext->SummFreq-minnum-(fs.Freq-1);

	for(PPMContext *currcontext=self->MedContext;currcontext!=self->MinContext;currcontext=ContextSuffix(currcontext,self))
	{
		int currnum=currcontext->NumStates;
		if(currnum!=1)
		{
			if((currnum&1)==0)
			{
				currcontext->States=ExpandUnits(&self->alloc,currcontext->States,currnum>>1);
				if(!currcontext->States) goto RESTART_MODEL;
			}
			if(4*currnum<=minnum&&currcontext->SummFreq<=8*currnum) currcontext->SummFreq+=2;
			if(2*currnum<minnum) currcontext->SummFreq++;
		}
		else
		{
			PPMState *states=OffsetToPointer(&self->alloc,AllocUnitsRare(&self->alloc,1));
			if(!states) goto RESTART_MODEL;
			states[0]=*(ContextOneState(currcontext));
			SetContextStatesPointer(currcontext,states,self);

			if(states[0].Freq<MAX_FREQ/4-1) states[0].Freq*=2;
			else states[0].Freq=MAX_FREQ-4;

			currcontext->SummFreq=states[0].Freq+self->InitEsc+(minnum>3?1:0);
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

		PPMState *currstates=ContextStates(currcontext,self);
		PPMState *new=&currstates[currnum];
		SetStateSuccessorPointer(new,Successor,self);
		new->Symbol=fs.Symbol;
		new->Freq=freq;
		currcontext->NumStates=currnum+1;
	}

	if(fs.Successor)
	{
		if(!StateSuccessor(&fs,self)->NumStates&&!MakeRoot(self,SkipCount,state)) goto RESTART_MODEL;
		self->MinContext=StateSuccessor(self->FoundState,self);
	}
	else
	{
		SetStateSuccessorPointer(self->FoundState,Successor,self);
		self->OrderFall++;
	}

	self->MedContext=self->MinContext;
	self->MaxContext=Successor;
	return;

	RESTART_MODEL:
	StartPPMdVariantGModel(self,NULL);
	self->EscCount=0;
}

static BOOL MakeRoot(PPMdVariantGModel *self,unsigned int SkipCount,PPMState *p1)
{
	PPMContext *pc=self->MinContext,*UpBranch=StateSuccessor(self->FoundState,self);
	PPMState *p,*ps[MAX_O],**pps=ps;

	if(SkipCount==0)
	{
		*pps++=self->FoundState;
		if(!pc->Suffix) goto NO_LOOP;
	}
	else if(SkipCount==2) pc=ContextSuffix(pc,self);

	if(p1)
	{
		p=p1;
		pc=ContextSuffix(pc,self);
		goto LOOP_ENTRY;
	}

	do
	{
		pc=ContextSuffix(pc,self);
		if(pc->NumStates!=1)
		{
			if((p=ContextStates(pc,self))->Symbol!=self->FoundState->Symbol)
			{
				do p++;
				while(p->Symbol!=self->FoundState->Symbol);
			}
		}
		else p=ContextOneState(pc);

		LOOP_ENTRY:
		if(StateSuccessor(p,self)!=UpBranch)
		{
			pc=StateSuccessor(p,self);
			break;
		}
		*pps++=p;
	}
	while(pc->Suffix);

	NO_LOOP: 0;
	PPMState *UpState=ContextOneState(UpBranch);
	if(pc->NumStates!=1)
	{
		unsigned int cf=UpState->Symbol;
		p=ContextStates(pc,self);
		while(p->Symbol!=cf) p++;

		unsigned int s0=pc->SummFreq-pc->NumStates-(cf=p->Freq-1);
		UpState->Freq=1+((2*cf<=s0)?(5*cf>s0):((2*cf+3*s0-1)/(2*s0)));
	}
	else UpState->Freq=ContextOneState(pc)->Freq;

	while(--pps>=ps)
	{
		pc=NewPPMContextWithContext(self,*pps,pc);
		if(!pc) return FALSE;
		*(ContextOneState(pc))=*UpState;
	}

	if(!self->OrderFall)
	{
		UpBranch->NumStates=1;
		SetContextSuffixPointer(UpBranch,pc,self);
	}

	return TRUE;
}

static void ClearMask(PPMdVariantGModel *self)
{
	self->EscCount=1;
	memset(self->CharMask,0,sizeof(self->CharMask));
}





static SEE2Context MakeSEE2(int initval)
{
	SEE2Context self;
	self.Shift=PERIOD_BITS-4;
	self.Summ=initval<<self.Shift;
	self.Count=3;
	return self;
}

static unsigned int GetSEE2Mean(SEE2Context *self)
{
	unsigned int retval=self->Summ>>self->Shift;
	self->Summ-=retval;
	retval&=0x03ff;
	if(retval==0) return 1;
	return retval;
}

static void UpdateSEE2(SEE2Context *self)
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




static PPMContext *StateSuccessor(PPMState *self,PPMdVariantGModel *model)
{ return OffsetToPointer(&model->alloc,self->Successor); }

static void SetStateSuccessorPointer(PPMState *self,PPMContext *newsuccessor,PPMdVariantGModel *model)
{ self->Successor=PointerToOffset(&model->alloc,newsuccessor); }

static PPMState *ContextStates(PPMContext *self,PPMdVariantGModel *model)
{ return OffsetToPointer(&model->alloc,self->States); }

static void SetContextStatesPointer(PPMContext *self, PPMState *newstates,PPMdVariantGModel *model)
{ self->States=PointerToOffset(&model->alloc,newstates); }

static PPMContext *ContextSuffix(PPMContext *self,PPMdVariantGModel *model)
{ return OffsetToPointer(&model->alloc,self->Suffix); } 

static void SetContextSuffixPointer(PPMContext *self,PPMContext *newsuffix,PPMdVariantGModel *model)
{ self->Suffix=PointerToOffset(&model->alloc,newsuffix); }

static PPMState *ContextOneState(PPMContext *self) { return (PPMState *)&self->SummFreq; }

static void InitPPMContext(PPMContext *self)
{
	self->NumStates=0;
	self->Suffix=0;
}

static void InitPPMContextWithContext(PPMContext *self,PPMState *pstats,PPMContext *shortercontext,PPMdVariantGModel *model)
{
	self->NumStates=1;
	SetContextSuffixPointer(self,shortercontext,model);
	SetStateSuccessorPointer(pstats,self,model);
}

static PPMContext *NewPPMContext(PPMdVariantGModel *model)
{
	PPMContext *context=OffsetToPointer(&model->alloc,AllocContext(&model->alloc));
	if(context) InitPPMContext(context);
	return context;
}

static PPMContext *NewPPMContextWithContext(PPMdVariantGModel *model,PPMState *pstats,PPMContext *shortercontext)
{
	PPMContext *context=OffsetToPointer(&model->alloc,AllocContext(&model->alloc));
	if(context) InitPPMContextWithContext(context,pstats,shortercontext,model);
	return context;
}


// Tabulated escapes for exponential symbol distribution
static const uint8_t ExpEscape[16]={ 25,14,9,7,5,5,4,4,4,3,3,3,2,2,2,2 };

#define GET_MEAN(SUMM,SHIFT,ROUND) ((SUMM+(1<<(SHIFT-ROUND)))>>(SHIFT))

static void DecodeBinSymbol(PPMContext *self,PPMdVariantGModel *model)
{
	PPMState *rs=ContextOneState(self);
	uint16_t *bs=&model->BinSumm[rs->Freq-1][model->PrevSuccess+model->NS2BSIndx[ContextSuffix(self,model)->NumStates-1]];

	if(RangeCoderCurrentCountWithShift(&model->coder,INT_BITS+PERIOD_BITS)<*bs)
	{
		model->SubRange.LowCount=0;
		model->SubRange.HighCount=*bs;
		model->PrevSuccess=1;
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


static void DecodeSymbol1(PPMContext *self,PPMdVariantGModel *model)
{
	model->SubRange.scale=self->SummFreq;

	PPMState *states=ContextStates(self,model);
	int firstcount=states[0].Freq;
	int count=RangeCoderCurrentCount(&model->coder,model->SubRange.scale);

	if(count<firstcount)
	{
		model->SubRange.HighCount=firstcount;
		model->PrevSuccess=(2*firstcount>model->SubRange.scale);

		model->FoundState=&states[0];
		states[0].Freq=firstcount+4;
		self->SummFreq+=4;

		if(firstcount+4>MAX_FREQ) RescaleContext(self,model);
		model->SubRange.LowCount=0;

		return;
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
			UpdateContext1(self,model,&states[i]);
			return;
		}
	}

	model->SubRange.LowCount=highcount;
	model->SubRange.HighCount=model->SubRange.scale;
	model->NumMasked=self->NumStates;
	model->FoundState=NULL;

	for(int i=0;i<self->NumStates;i++) model->CharMask[states[i].Symbol]=model->EscCount;
}

static void UpdateContext1(PPMContext *self,PPMdVariantGModel *model,PPMState *state)
{
	state->Freq+=4;
	self->SummFreq+=4;

	if(state[0].Freq>state[-1].Freq)
	{
		SWAP(state[0],state[-1]);
		model->FoundState=&state[-1];
		if(state[-1].Freq>MAX_FREQ) RescaleContext(self,model);
	}
	else
	{
		model->FoundState=state;
	}
}



static void DecodeSymbol2(PPMContext *self,PPMdVariantGModel *model)
{
	int n=self->NumStates-model->NumMasked;
	SEE2Context *psee2c=MakeEscFreq2(self,model,n);
	PPMState *ps[256];

	int total=0;
	PPMState *state=ContextStates(self,model);
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
		UpdateSEE2(psee2c);
		UpdateContext2(self,model,ps[i]);
	}
	else
	{
		model->SubRange.LowCount=total;
		model->SubRange.HighCount=model->SubRange.scale;
		model->NumMasked=self->NumStates;
		psee2c->Summ+=model->SubRange.scale;

		for(int i=0;i<n;i++) model->CharMask[ps[i]->Symbol]=model->EscCount;
	}
}

static SEE2Context *MakeEscFreq2(PPMContext *self,PPMdVariantGModel *model,int Diff)
{
	if(self->NumStates!=256)
	{
		SEE2Context *psee2c=&model->SEE2Cont[model->NS2Indx[Diff-1]][
			+(Diff<ContextSuffix(self,model)->NumStates-self->NumStates?1:0)
			+(self->SummFreq<11*self->NumStates?2:0)
			+(model->NumMasked>Diff?4:0)];
		model->SubRange.scale=GetSEE2Mean(psee2c);
		return psee2c;
	}
	else
	{
		model->SubRange.scale=1;
		return &model->DummySEE2Cont;
	}
}

static void UpdateContext2(PPMContext *self,PPMdVariantGModel *model,PPMState *state)
{
	model->FoundState=state;
	state->Freq+=4;
	self->SummFreq+=4;
	if(state->Freq>MAX_FREQ) RescaleContext(self,model);
	model->EscCount++;
}

static void RescaleContext(PPMContext *self,PPMdVariantGModel *model)
{
	PPMState *states=ContextStates(self,model);
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
			PPMState tmp=states[i];

			int j=i-1;
			while(j>0&&tmp.Freq>states[j-1].Freq) j--;

			memmove(&states[j+1],&states[j],sizeof(PPMState)*(i-j));
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
			PPMState tmp=states[0];
			do
			{
				tmp.Freq=(tmp.Freq+1)>>1;
				escfreq>>=1;
			}
			while(escfreq>1);

			FreeUnits(&model->alloc,self->States,(n+1)>>1);
			model->FoundState=ContextOneState(self);
			*model->FoundState=tmp;

			return;
		}

		int n0=(n+1)>>1,n1=(self->NumStates+1)>>1;
		if(n0!=n1) self->States=ShrinkUnits(&model->alloc,self->States,n0,n1);
	}

	self->SummFreq+=(escfreq+1)>>1;

	// The found state is the first one to breach the limit, thus it is the largest and also first
	model->FoundState=ContextStates(self,model);
}
