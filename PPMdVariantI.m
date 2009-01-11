#import "PPMdVariantI.h"

static void UpdateModel(PPMdVariantIModel *self,PPMdContext *MinContext);
static PPMdContext *CreateSuccessors(PPMdVariantIModel *self,BOOL skip,PPMdState *p1,PPMdContext *MinContext);
static PPMdContext *ReduceOrder(PPMdVariantIModel *self,PPMdState *p,PPMdContext *pc);
static void RestoreModel(PPMdVariantIModel *self,PPMdContext *pc1,PPMdContext *MinContext,PPMdContext *FSuccessor);

static void RefreshContext(PPMdContext *self,int OldNU,BOOL Scale,PPMdVariantIModel *model);
static PPMdContext *CutOffContext(PPMdContext *self,int Order,PPMdVariantIModel *model);
static PPMdContext *RemoveBinConts(PPMdContext *self,int Order,PPMdVariantIModel *model);

static void DecodeBinSymbolVariantI(PPMdContext *self,PPMdVariantIModel *model);
static void DecodeSymbol1VariantI(PPMdContext *self,PPMdVariantIModel *model);
static void DecodeSymbol2VariantI(PPMdContext *self,PPMdVariantIModel *model);

static void RescalePPMdContextVariantI(PPMdContext *self,PPMdVariantIModel *model);



void StartPPMdVariantIModel(PPMdVariantIModel *self,CSInputBuffer *input,int maxorder,int mrmethod)
{
    memset(self->core.CharMask,0,sizeof(self->core.CharMask));

	if(input) InitializeRangeCoder(&self->core.coder,input);

	if(maxorder<2) // TODO: solid mode
	{
		self->core.OrderFall=self->MaxOrder;
		for(PPMdContext *pc=self->MaxContext;pc->Suffix;pc=PPMdContextSuffix(pc,&self->core))
		self->core.OrderFall--;
		return;
	}

	self->alloc=(PPMdSubAllocatorVariantI *)self->core.alloc; // A bit ugly but there you go.

	InitSubAllocator(self->core.alloc);

	self->core.RescalePPMdContext=(void *)RescalePPMdContextVariantI;

	self->MaxOrder=self->core.OrderFall=maxorder;
	self->MRMethod=mrmethod;
	self->core.EscCount=1;
	self->core.PrevSuccess=0;
	self->core.RunLength=self->core.InitRL=-((self->MaxOrder<12)?self->MaxOrder:12)-1;

	self->MaxContext=NewPPMdContext(&self->core);
	self->MaxContext->LastStateIndex=255;
	self->MaxContext->SummFreq=257;
	self->MaxContext->States=AllocUnits(self->core.alloc,256/2);

	PPMdState *maxstates=PPMdContextStates(self->MaxContext,&self->core);
	for(int i=0;i<256;i++)
	{
		maxstates[i].Symbol=i;
		maxstates[i].Freq=1;
		maxstates[i].Successor=0;
	}

	self->NS2BSIndx[0]=2*0; // this is constant
	self->NS2BSIndx[1]=2*1;
	for(int i=2;i<11;i++) self->NS2BSIndx[i]=2*2;
	for(int i=11;i<256;i++) self->NS2BSIndx[i]=2*3;

	for(int i=0;i<UP_FREQ;i++) self->QTable[i]=i; // also constant
	int m,i,k,Step;
	for (m=i=UP_FREQ, k=Step=1;i<260;i++)
	{
		self->QTable[i]=m;
		if ( !--k ) { k = ++Step; m++; }
    }

	static const uint16_t InitBinEsc[8]={0x3cdd,0x1f3f,0x59bf,0x48f3,0x64a1,0x5abc,0x6632,0x6051};

/*	for(int i=0;i<128;i++)
	for(int k=0;k<8;k++)
	for(int m=0;m<64;m+=8)
	self->BinSumm[i][k+m]=BIN_SCALE-InitBinEsc[k]/(i+2);*/

	i=0;
	for(int m=0;m<25;m++)
	{
		while(self->QTable[i]==m) i++;
		for(int k=0;k<8;k++) self->BinSumm[m][k]=BIN_SCALE-InitBinEsc[k]/(i+1);
		for(int k=8;k<64;k+=8) memcpy(&self->BinSumm[m][k],&self->BinSumm[m][0],8*sizeof(uint16_t));
	}

	i=0;
	for(int m=0;m<24;m++)
	{
		while(self->QTable[i+3]==m+3) i++;
        for(int k=0;k<32;k++) self->SEE2Cont[m][k]=MakeSEE2(2*i+5,7);
    }

	self->DummySEE2Cont.Summ=0xaf8f;
	//self->DummySEE2Cont.Shift=0xac;
	self->DummySEE2Cont.Count=0x84;
	self->DummySEE2Cont.Shift=PERIOD_BITS;
}


int NextPPMdVariantIByte(PPMdVariantIModel *self)
{
	PPMdContext *MinContext=self->MaxContext;

	if(MinContext->LastStateIndex!=0) DecodeSymbol1VariantI(MinContext,self);
	else DecodeBinSymbolVariantI(MinContext,self);

	RemoveRangeCoderSubRange(&self->core.coder,self->core.SubRange.LowCount,self->core.SubRange.HighCount);

	while(!self->core.FoundState)
	{
		NormalizeRangeCoderWithBottom(&self->core.coder,1<<15);
		do
		{
			self->core.OrderFall++;
			MinContext=PPMdContextSuffix(MinContext,&self->core);
			if(!MinContext) return -1;
		}
		while(MinContext->LastStateIndex==self->core.LastMaskIndex);

		DecodeSymbol2VariantI(MinContext,self);
		RemoveRangeCoderSubRange(&self->core.coder,self->core.SubRange.LowCount,self->core.SubRange.HighCount);
	}

	uint8_t byte=self->core.FoundState->Symbol;

	if(!self->core.OrderFall&&(uint8_t *)PPMdStateSuccessor(self->core.FoundState,&self->core)>=self->alloc->UnitsStart)
	{
		self->MaxContext=PPMdStateSuccessor(self->core.FoundState,&self->core);
		//PrefetchData(MaxContext)
	}
	else
	{
		UpdateModel(self,MinContext);
		//PrefetchData(MaxContext)
		if(self->core.EscCount==0) ClearPPMdModelMask(&self->core);
	}

	NormalizeRangeCoderWithBottom(&self->core.coder,1<<15);

	return byte;
}

static void UpdateModel(PPMdVariantIModel *self,PPMdContext *MinContext)
{
	PPMdState fs=*self->core.FoundState;
	PPMdState *state=NULL;
	PPMdContext *currcontext=self->MaxContext;

	if(fs.Freq<MAX_FREQ/4&&MinContext->Suffix)
	{
		PPMdContext *context=PPMdContextSuffix(MinContext,&self->core);
		if(context->LastStateIndex!=0)
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

			if(state->Freq<MAX_FREQ-9)
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

	if(self->core.OrderFall==0&&fs.Successor)
	{
		PPMdContext *newsuccessor=CreateSuccessors(self,YES,state,MinContext);
		SetPPMdStateSuccessorPointer(self->core.FoundState,newsuccessor,&self->core);
		if(!newsuccessor) goto RESTART_MODEL;
		self->MaxContext=newsuccessor;
		return;
	}

	*self->alloc->pText++=fs.Symbol;
	PPMdContext *Successor=(PPMdContext *)self->alloc->pText;

	if(self->alloc->pText>=self->alloc->UnitsStart) goto RESTART_MODEL;

	if(fs.Successor)
	{
		if((uint8_t *)PPMdStateSuccessor(&fs,&self->core)<self->alloc->UnitsStart)
		{
			SetPPMdStateSuccessorPointer(&fs,CreateSuccessors(self,NO,state,MinContext),&self->core);
		}
	}
	else
	{
		SetPPMdStateSuccessorPointer(&fs,ReduceOrder(self,state,MinContext),&self->core);
	}

	if(!fs.Successor) goto RESTART_MODEL;

	if(--self->core.OrderFall==0)
	{
		Successor=PPMdStateSuccessor(&fs,&self->core);
		if(self->MaxContext!=MinContext) self->alloc->pText--;
	}
	else if(self->MRMethod>MRM_FREEZE)
	{
		Successor=PPMdStateSuccessor(&fs,&self->core);
		self->alloc->pText=self->alloc->HeapStart;
		self->core.OrderFall=0;
	}

	int minnum=MinContext->LastStateIndex+1;
	int s0=MinContext->SummFreq-minnum-(fs.Freq-1);
	uint8_t flag=fs.Symbol>=0x40?8:0;

	for(;currcontext!=MinContext;currcontext=PPMdContextSuffix(currcontext,&self->core))
	{
		int currnum=currcontext->LastStateIndex+1;
		if(currnum!=1)
		{
			if((currnum&1)==0)
			{
				uint32_t states=ExpandUnits(self->core.alloc,currcontext->States,currnum>>1);
				if(!states) goto RESTART_MODEL;
				currcontext->States=states;
			}
			if(3*currnum-1<minnum) currcontext->SummFreq++;
		}
		else
		{
			PPMdState *states=OffsetToPointer(self->core.alloc,AllocUnits(self->core.alloc,1));
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
			currcontext->SummFreq+=4;
		}
		else
		{
			if(cf>15*sf) freq=7;
			else if(cf>12*sf) freq=6;
			else if(cf>9*sf) freq=5;
			else freq=4;
			currcontext->SummFreq+=freq;
		}

		currcontext->LastStateIndex++;
		PPMdState *currstates=PPMdContextStates(currcontext,&self->core);
		PPMdState *new=&currstates[currcontext->LastStateIndex];
		SetPPMdStateSuccessorPointer(new,Successor,&self->core);
		new->Symbol=fs.Symbol;
		new->Freq=freq;
		currcontext->Flags|=flag;
	}

	self->MaxContext=PPMdStateSuccessor(&fs,&self->core);

	return;

	RESTART_MODEL:
	RestoreModel(self,currcontext,MinContext,PPMdStateSuccessor(&fs,&self->core));
}

static PPMdContext *CreateSuccessors(PPMdVariantIModel *self,BOOL skip,PPMdState *p,PPMdContext *pc)
{
	PPMdContext ct,*UpBranch=PPMdStateSuccessor(self->core.FoundState,&self->core);
	PPMdState *ps[MAX_O],**pps=ps;
	unsigned int cf,s0;
	uint8_t tmp,sym=self->core.FoundState->Symbol;
 
	if(!skip)
	{
		*pps++=self->core.FoundState;
		if(!pc->Suffix) goto NO_LOOP;
	}

	if(p)
	{
		pc=PPMdContextSuffix(pc,&self->core);
		goto LOOP_ENTRY;
	}

	do
	{
		pc=PPMdContextSuffix(pc,&self->core);
		if(pc->LastStateIndex!=0)
		{
			if((p=PPMdContextStates(pc,&self->core))->Symbol!=sym)
			do { tmp=p[1].Symbol; p++; } while(tmp!=sym);

			tmp=(p->Freq<MAX_FREQ-9);
			p->Freq+=tmp;
			pc->SummFreq+=tmp;
		}
		else
		{
			p=PPMdContextOneState(pc);
			p->Freq+=(!PPMdContextSuffix(pc,&self->core)->LastStateIndex&(p->Freq<24));
		}

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

	if(pps==ps) return pc;

	ct.LastStateIndex=0;
	ct.Flags=0x10*(sym>=0x40);
	PPMdContextOneState(&ct)->Symbol=sym=*(uint8_t *)UpBranch;
	SetPPMdStateSuccessorPointer(PPMdContextOneState(&ct),(PPMdContext *)(((uint8_t *)UpBranch)+1),&self->core);
	ct.Flags|=0x08*(sym>=0x40);

	if(pc->LastStateIndex)
	{
		if((p=PPMdContextStates(pc,&self->core))->Symbol!=sym)
		do { tmp=p[1].Symbol; p++; } while(tmp!=sym);

		s0=pc->SummFreq-pc->LastStateIndex-(cf=p->Freq-1);
		PPMdContextOneState(&ct)->Freq=1+((2*cf<=s0)?(5*cf>s0):((cf+2*s0-3)/s0));
	}
	else PPMdContextOneState(&ct)->Freq=PPMdContextOneState(pc)->Freq;

	do
	{
		PPMdContext *pc1=(PPMdContext *)OffsetToPointer(self->core.alloc,AllocContext(self->core.alloc));
		if(!pc1) return NULL;
		((uint32_t *)pc1)[0]=((uint32_t *)&ct)[0];
		((uint32_t *)pc1)[1]=((uint32_t *)&ct)[1];
		SetPPMdContextSuffixPointer(pc1,pc,&self->core);
		SetPPMdStateSuccessorPointer(*--pps,pc=pc1,&self->core);
	}
	while(pps!=ps);

	return pc;
}

static PPMdContext *ReduceOrder(PPMdVariantIModel *self,PPMdState *p,PPMdContext *pc)
{
	PPMdState *p1,*ps[MAX_O],**pps=ps;
	PPMdContext *pc1=pc,*UpBranch=(PPMdContext *)self->alloc->pText;
	uint8_t tmp,sym=self->core.FoundState->Symbol;
    *pps++=self->core.FoundState;
	SetPPMdStateSuccessorPointer(self->core.FoundState,UpBranch,&self->core);
	self->core.OrderFall++;

    if(p)
    {
		pc=PPMdContextSuffix(pc,&self->core);
		goto LOOP_ENTRY;
	}

	for(;;)
	{
		if(!pc->Suffix)
		{
			if(self->MRMethod>MRM_FREEZE)
			{
FROZEN:
				do SetPPMdStateSuccessorPointer(*--pps,pc,&self->core);
				while (pps!=ps);
				self->alloc->pText=self->alloc->HeapStart+1;
				self->core.OrderFall=1;
			}
			return pc;
		}
        pc=PPMdContextSuffix(pc,&self->core);

		if(pc->LastStateIndex)
		{
			if((p=PPMdContextStates(pc,&self->core))->Symbol!=sym)
			do { tmp=p[1].Symbol;   p++; } while (tmp !=sym);

			tmp=2*(p->Freq < MAX_FREQ-9);
			p->Freq += tmp;
			pc->SummFreq += tmp;
		}
		else
		{
			p=PPMdContextOneState(pc);
			p->Freq += (p->Freq < 32);
		}
LOOP_ENTRY:
		if(p->Successor) break;
		*pps++ = p;
		SetPPMdStateSuccessorPointer(p,UpBranch,&self->core);
		self->core.OrderFall++;
	}
	if(self->MRMethod>MRM_FREEZE)
	{
		pc=PPMdStateSuccessor(p,&self->core);
		goto FROZEN;
	}
	else if (PPMdStateSuccessor(p,&self->core) <= UpBranch)
	{
		p1=self->core.FoundState;
		self->core.FoundState=p;
        SetPPMdStateSuccessorPointer(p,CreateSuccessors(self,NO,NULL,pc),&self->core);
		self->core.FoundState=p1;
	}
	if(self->core.OrderFall==1&&pc1==self->MaxContext)
	{
		SetPPMdStateSuccessorPointer(self->core.FoundState,PPMdStateSuccessor(p,&self->core),&self->core);
		self->alloc->pText--;
	}

	return PPMdStateSuccessor(p,&self->core);
}


static void RestoreModel(PPMdVariantIModel *self,PPMdContext *pc1,PPMdContext *MinContext,PPMdContext *FSuccessor)
{
	PPMdContext *pc;
	PPMdState *p;

	for(pc=self->MaxContext,self->alloc->pText=self->alloc->HeapStart;pc!=pc1;pc=PPMdContextSuffix(pc,&self->core))
	if(--(pc->LastStateIndex)==0)
	{
		pc->Flags=(pc->Flags&0x10)+0x08*(PPMdContextStates(pc,&self->core)[0].Symbol>=0x40);
		p=PPMdContextStates(pc,&self->core);
		*(PPMdContextOneState(pc))=*p;
		SpecialFreeUnitVariantI(self->alloc,PointerToOffset(self->core.alloc,p));
		PPMdContextOneState(pc)->Freq=(PPMdContextOneState(pc)->Freq+11)>>3;
	}
	else RefreshContext(pc,(pc->LastStateIndex+3)>>1,NO,self);

	for(;pc!=MinContext;pc=PPMdContextSuffix(pc,&self->core))
	if(!pc->LastStateIndex) PPMdContextOneState(pc)->Freq-=PPMdContextOneState(pc)->Freq>>1;
	else if((pc->SummFreq+=4)>128+4*pc->LastStateIndex) RefreshContext(pc,(pc->LastStateIndex+2)>>1,YES,self);

	if(self->MRMethod>MRM_FREEZE)
	{
		self->MaxContext=FSuccessor;
		self->alloc->GlueCount+=!(self->alloc->BList[1].Stamp&1);
	}
	else if(self->MRMethod==MRM_FREEZE)
	{
		while(self->MaxContext->Suffix)
		self->MaxContext=PPMdContextSuffix(self->MaxContext,&self->core);

		RemoveBinConts(self->MaxContext,0,self);
		self->MRMethod=self->MRMethod+1;
		self->alloc->GlueCount=0;
		self->core.OrderFall=self->MaxOrder;
	}
	else if(self->MRMethod==MRM_RESTART||GetUsedMemoryVariantI(self->alloc)<(self->alloc->SubAllocatorSize>>1))
	{
		StartPPMdVariantIModel(self,NULL,self->MaxOrder,self->MRMethod);
		self->core.EscCount=0;
	}
	else
	{
		while(self->MaxContext->Suffix) self->MaxContext=PPMdContextSuffix(self->MaxContext,&self->core);
		do
		{
			CutOffContext(self->MaxContext,0,self);
			ExpandTextAreaVariantI(self->alloc);
		} while(GetUsedMemoryVariantI(self->alloc)>3*(self->alloc->SubAllocatorSize>>2));

		self->alloc->GlueCount=0;
		self->core.OrderFall=self->MaxOrder;
	}
}




// TODO: rescale!

static void RefreshContext(PPMdContext *self,int OldNU,BOOL Scale,PPMdVariantIModel *model)
{
	int i=self->LastStateIndex,EscFreq;

	self->States=ShrinkUnits(model->core.alloc,self->States,OldNU,(i+2)>>1);
	PPMdState *p=PPMdContextStates(self,&model->core);

	self->Flags=(self->Flags&(0x10+0x04*Scale))+0x08*(p->Symbol>=0x40);
	EscFreq=self->SummFreq-p->Freq;

	self->SummFreq=(p->Freq=(p->Freq+Scale)>>Scale);

	do
	{
		EscFreq-=(++p)->Freq;
		self->SummFreq+=(p->Freq=(p->Freq+Scale)>>Scale);
		self->Flags|=0x08*(p->Symbol>=0x40);
	}
	while(--i);

	self->SummFreq+=(EscFreq=(EscFreq+Scale)>>Scale);
}

static PPMdContext *CutOffContext(PPMdContext *self,int Order,PPMdVariantIModel *model)
{
	int i,tmp;
	PPMdState *p;

	if(!self->LastStateIndex)
	{
		if((uint8_t *)PPMdStateSuccessor(p=PPMdContextOneState(self),&model->core)>=model->alloc->UnitsStart)
		{
			if(Order<model->MaxOrder)
			{
				//PrefetchData(p->Successor);
				SetPPMdStateSuccessorPointer(p,
				CutOffContext(PPMdStateSuccessor(p,&model->core),Order+1,model),
				&model->core);
			}
            else p->Successor=0;

			if(!p->Successor&&Order>O_BOUND) goto REMOVE;

			return self;
        }
		else
		{
REMOVE:
			SpecialFreeUnitVariantI(model->alloc,PointerToOffset(model->core.alloc,self));
			return NULL;
		}
	}
	//PrefetchData(self->States);

	self->States=MoveUnitsUpVariantI(model->alloc,self->States,tmp=(self->LastStateIndex+2)>>1);

	for(p=PPMdContextStates(self,&model->core)+(i=self->LastStateIndex);p>=PPMdContextStates(self,&model->core);p--)
	if((uint8_t *)PPMdStateSuccessor(p,&model->core)<model->alloc->UnitsStart)
	{
		p->Successor=0;
		SWAP(*p,PPMdContextStates(self,&model->core)[i]);
		i--;
	}
	else if(Order<model->MaxOrder)
	{
		//PrefetchData(p->Successor);
		SetPPMdStateSuccessorPointer(p,
		CutOffContext(PPMdStateSuccessor(p,&model->core),Order+1,model),
		&model->core);
	}
	else p->Successor=0;

	if(i!=self->LastStateIndex&&Order)
	{
		self->LastStateIndex=i;
		p=PPMdContextStates(self,&model->core);

		if(i<0)
		{
			FreeUnits(model->core.alloc,PointerToOffset(model->core.alloc,p),tmp);
			goto REMOVE;
		}
        else if(i==0)
		{
			self->Flags=(self->Flags&0x10)+0x08*(p->Symbol>=0x40);
			*(PPMdContextOneState(self))=*p;
			FreeUnits(model->core.alloc,PointerToOffset(model->core.alloc,p),tmp);
			PPMdContextOneState(self)->Freq=(PPMdContextOneState(self)->Freq+11)>>3;
		}
		else RefreshContext(self,tmp,self->SummFreq>16*i,model);
	}
	return self;
}

static PPMdContext *RemoveBinConts(PPMdContext *self,int Order,PPMdVariantIModel *model)
{
	PPMdState *p;

	if(!self->LastStateIndex)
	{
		p=PPMdContextOneState(self);
		if((uint8_t *)PPMdStateSuccessor(p,&model->core)>=model->alloc->UnitsStart&&Order<model->MaxOrder)
		{
			//PrefetchData(p->Successor);
			SetPPMdStateSuccessorPointer(p,
			RemoveBinConts(PPMdStateSuccessor(p,&model->core),Order+1,model),
			&model->core);
		}
        else p->Successor=0;

		if(!p->Successor&&(!PPMdContextSuffix(self,&model->core)->LastStateIndex
		||PPMdContextSuffix(self,&model->core)->Flags==0xff))
		{
			FreeUnits(model->core.alloc,PointerToOffset(model->core.alloc,self),1);
			return NULL;
        }
		else return self;
    }
	//PrefetchData(self->States);
	for(p=PPMdContextStates(self,&model->core)+self->LastStateIndex;p>=PPMdContextStates(self,&model->core);p--)
	if((uint8_t *)PPMdStateSuccessor(p,&model->core)>=model->alloc->UnitsStart&&Order<model->MaxOrder)
	{
		//PrefetchData(p->Successor);
		SetPPMdStateSuccessorPointer(p,
		RemoveBinConts(PPMdStateSuccessor(p,&model->core),Order+1,model),
		&model->core);
	}
	else p->Successor=0;

	return self;
}





static void DecodeBinSymbolVariantI(PPMdContext *self,PPMdVariantIModel *model)
{
	PPMdState *rs=PPMdContextOneState(self);

	uint8_t index=model->NS2BSIndx[PPMdContextSuffix(self,&model->core)->LastStateIndex]+model->core.PrevSuccess+self->Flags;
	uint16_t *bs=&model->BinSumm[model->QTable[rs->Freq-1]][index+((model->core.RunLength>>26)&0x20)];

	PPMdDecodeBinSymbol(self,&model->core,bs,196);
}

static void DecodeSymbol1VariantI(PPMdContext *self,PPMdVariantIModel *model)
{
	PPMdDecodeSymbol1(self,&model->core,YES);
}

static void DecodeSymbol2VariantI(PPMdContext *self,PPMdVariantIModel *model)
{
	SEE2Context *see;

	//uint8_t *pb=(uint8_t *)PPMdContextStates(self);
	//unsigned int t=2*self->LastStateIndex;
	//PrefetchData(pb);
	//PrefetchData(pb+t);
	//PrefetchData(pb+2*t);
	//PrefetchData(pb+3*t);

	if(self->LastStateIndex!=255)
	{
		int n=PPMdContextSuffix(self,&model->core)->LastStateIndex;
 		see=&model->SEE2Cont[model->QTable[self->LastStateIndex+2]-3][
			(self->SummFreq>11*(self->LastStateIndex+1)?1:0)
			+(2*self->LastStateIndex<n+model->core.LastMaskIndex?2:0)
			+self->Flags];
		model->core.SubRange.scale=GetSEE2Mean(see);
	}
	else
	{
		model->core.SubRange.scale=1;
		see=&model->DummySEE2Cont;
	}

	PPMdDecodeSymbol2(self,&model->core,see);
}

static void RescalePPMdContextVariantI(PPMdContext *self,PPMdVariantIModel *model)
{
	PPMdState *states=PPMdContextStates(self,&model->core);
	int n=self->LastStateIndex+1;

	// Bump frequency of found state
	model->core.FoundState->Freq+=4;

	// Divide all frequencies and sort list
	int escfreq=self->SummFreq+4;
	int adder=(model->core.OrderFall!=0||model->MRMethod>MRM_FREEZE?1:0);
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

		self->LastStateIndex-=numzeros;
		if(self->LastStateIndex==0)
		{
			PPMdState tmp=states[0];

			tmp.Freq=(2*tmp.Freq+escfreq-1)/escfreq;
			if(tmp.Freq>MAX_FREQ/3) tmp.Freq=MAX_FREQ/3;

			FreeUnits(model->core.alloc,self->States,(n+1)>>1);
			model->core.FoundState=PPMdContextOneState(self);
			*model->core.FoundState=tmp;

			self->Flags=(self->Flags&0x10)+0x08*(tmp.Symbol>=0x40);

			return;
		}

		self->States=ShrinkUnits(model->core.alloc,self->States,(n+1)>>1,(self->LastStateIndex+2)>>1);

		PPMdState *p=PPMdContextStates(self,&model->core);
		self->Flags&=~0x08;
		int i=self->LastStateIndex;
		self->Flags|=0x08*(p->Symbol>=0x40);
        do self->Flags|=0x08*((++p)->Symbol>=0x40);
		while (--i);
	}

	self->SummFreq+=(escfreq+1)>>1;
	self->Flags|=0x04; 

	// The found state is the first one to breach the limit, thus it is the largest and also first
	model->core.FoundState=PPMdContextStates(self,&model->core);
}
