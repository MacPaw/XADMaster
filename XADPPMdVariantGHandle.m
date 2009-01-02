#import "XADPPMdVariantGHandle.h"

static void StartModel(PPMModel *self);
static void UpdateModel(PPMModel *self);
static BOOL MakeRoot(PPMModel *self,unsigned int SkipCount,PPMState *p1);
static void ClearMask(PPMModel *self);

PPMState *ContextOneState(PPMContext *self);
static void InitPPMContext(PPMContext *self);
static void InitPPMContextWithContext(PPMContext *self,PPMState *pstats,PPMContext *shortercontext);
static PPMContext *NewPPMContext(PPMSubAllocator *alloc);
static PPMContext *NewPPMContextWithContext(PPMSubAllocator *alloc,PPMState *pstats,PPMContext *shortercontext);

static void DecodeBinSymbol(PPMContext *self,PPMModel *model);
static void DecodeSymbol1(PPMContext *self,PPMModel *model);
static void UpdateContext1(PPMContext *self,PPMModel *model,PPMState *p);
static void DecodeSymbol2(PPMContext *self,PPMModel *model);
static SEE2Context *MakeEscFreq2(PPMContext *self,PPMModel *model,int Diff);
static void UpdateContext2(PPMContext *self,PPMModel *model,PPMState *p);
static void RescaleContext(PPMContext *self,PPMModel *model);

@implementation XADPPMdVariantGHandle

-(id)initWithHandle:(CSHandle *)handle maxOrder:(int)maxorder subAllocSize:(int)suballocsize
{
	return [self initWithHandle:handle length:/*CSHandleMaxLength*/0x7fffffffffffffffLL maxOrder:maxorder subAllocSize:suballocsize];
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length maxOrder:(int)maxorder subAllocSize:(int)suballocsize
{
	if(self=[super initWithHandle:handle length:length])
	{
		StartSubAllocator(&alloc,suballocsize);
		MaxOrder=maxorder;
	}
	return self;
}

-(void)dealloc
{
	StopSubAllocator(&alloc);
	[super dealloc];
}

#define TOP (1<<24)
#define BOT (1<<15)

void ariInitEncoder(PPMModel *model)
{
	model->low=0;
	model->range=-1;
}


#define ARI_INIT_DECODER(model) {                                          \
    model->low=model->code=0; model->range=-1;                \
    for (int i=0;i < 4;i++) model->code=(model->code << 8) | CSInputNextByte(model->input);\
}

#define ARI_DEC_NORMALIZE(model) {                                         \
    while ((model->low ^ (model->low+model->range)) < TOP || model->range < BOT &&     \
            ((model->range= -model->low & (BOT-1)),1)) {                               \
        model->code=(model->code << 8) | CSInputNextByte(model->input);           \
        model->range <<= 8;                        model->low <<= 8;                      \
    }                                                                       \
}

int ariGetCurrentCount(PPMModel *model) {
    return (model->code-model->low)/(model->range /= model->SubRange.scale);
}
unsigned int ariGetCurrentShiftCount(PPMModel *model,unsigned int SHIFT) {
    return (model->code-model->low)/(model->range >>= SHIFT);
}
void ariRemoveSubrange(PPMModel *model)
{
    model->low += model->range*model->SubRange.LowCount;
    model->range *= model->SubRange.HighCount-model->SubRange.LowCount;
}

-(void)resetByteStream
{
	ARI_INIT_DECODER(self);
	StartModel(self);
}

-(uint8_t)produceByteAtOffset:(off_t)pos
{
if(pos==723)
NSLog(@"%x %x %x",low,code,range);
	if(MinContext->NumStats!=1)	DecodeSymbol1(MinContext,self);
	else DecodeBinSymbol(MinContext,self);

	ariRemoveSubrange(self);

	while(!self->FoundState)
	{
		ARI_DEC_NORMALIZE(self);
		do
		{
			self->OrderFall++;
			MinContext=MinContext->Suffix;
			if(!MinContext) CSByteStreamEOF(self);
		}
		while(MinContext->NumStats==self->NumMasked);

		DecodeSymbol2(MinContext,self);
		ariRemoveSubrange(self);
	}

	uint8_t byte=self->FoundState->Symbol;

//fprintf(stderr,"%02x ",byte);
//if((pos&15)==15) fprintf(stderr,"\n");
	if(!self->OrderFall&&self->FoundState->Successor->NumStats) MinContext=self->MedContext=self->FoundState->Successor;
	else
	{
		UpdateModel(self);
		if(self->EscCount==0) ClearMask(self);
	}
	ARI_DEC_NORMALIZE(self);

	return byte;
}

#define MAX_O 16
#define INT_BITS 7
#define PERIOD_BITS 7
#define MAX_FREQ 124
#define INTERVAL (1<<INT_BITS)
#define BIN_SCALE (INTERVAL<<PERIOD_BITS)

#define SWAP(t1,t2) { PPMState tmp=(t1); (t1)=(t2); (t2)=tmp; }

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
	if(--self->Count==0)
	{
		self->Summ*=2;
		self->Count=3<<self->Shift;
		self->Shift++;
	}
}



static void StartModel(PPMModel *self)
{
	InitSubAllocator(&self->alloc);

	self->MaxContext=NewPPMContext(&self->alloc);
	self->MaxContext->Suffix=NULL;
	self->MaxContext->NumStats=256;
	self->MaxContext->SummFreq=257;
	self->MaxContext->Stats=(PPMState *)AllocUnitsRare(&self->alloc,256/2);
	self->PrevSuccess=0;

	for(int i=0;i<256;i++)
	{
		self->MaxContext->Stats[i].Symbol=i;
		self->MaxContext->Stats[i].Freq=1;
		self->MaxContext->Stats[i].Successor=NULL;
	}

	self->OrderFall=1;
	PPMState *p=self->MaxContext->Stats;
	for(int i=1;;i++)
	{
		self->MaxContext=NewPPMContextWithContext(&self->alloc,p,self->MaxContext);
		if(i==self->MaxOrder) break;
		p=ContextOneState(self->MaxContext);
        p->Symbol=0;
		p->Freq=1;
    }

	self->MaxContext->NumStats=0;
	self->MedContext=self->MinContext=self->MaxContext->Suffix;

	static const uint16_t InitBinEsc[16]=
	{
		0x3CDD,0x1F3F,0x59BF,0x48F3,0x5FFB,0x5545,0x63D1,0x5D9D,
		0x64A1,0x5ABC,0x6632,0x6051,0x68F6,0x549B,0x6BCA,0x3AB0,
	};

	for(int i=0;i<128;i++)
	for(int k=0;k<16;k++)
	self->BinSumm[i][k]=BIN_SCALE-InitBinEsc[k]/(i+2);

	int i=0;
    for(;i<6;i++) self->NS2BSIndx[i]=2*i;
    for(;i<50;i++) self->NS2BSIndx[i]=12;
    for(;i<256;i++) self->NS2BSIndx[i]=14;

	for(int i=0;i<43;i++)
	for(int k=0;k<8;k++)
	self->SEE2Cont[i][k]=MakeSEE2(4*i+10);

    self->SEE2Cont[43][0].Shift=PERIOD_BITS;

	i=0;
    for(;i<4;i++) self->NS2Indx[i]=i;
    for(;i<4+8;i++) self->NS2Indx[i]=4+((i-4)>>1);
    for(;i<4+8+32;i++) self->NS2Indx[i]=4+4+((i-4-8)>>2);
    for(;i<256;i++) self->NS2Indx[i]=4+4+8+((i-4-8-32)>>3);

    memset(self->CharMask,0,sizeof(self->CharMask));
	self->EscCount=self->PrintCount=1;
}

static void UpdateModel(PPMModel *self)
{
	PPMState fs=*self->FoundState,*p,*p1=NULL;
	PPMContext *pc,*Successor;
	unsigned int ns1,ns,cf,sf,s0,SkipCount=0;

	if(fs.Freq<MAX_FREQ/4&&(pc=self->MinContext->Suffix)!=NULL)
	{
		if(pc->NumStats!=1)
		{
			if((p1=pc->Stats)->Symbol!=fs.Symbol)
			{
				do p1++;
				while(p1->Symbol!=fs.Symbol);

				if(p1[0].Freq>=p1[-1].Freq)
				{
					SWAP(p1[0],p1[-1]); p1--;
				}
			}
			if(p1->Freq<7*MAX_FREQ/8)
			{
				p1->Freq+=2;
				pc->SummFreq+=2;
			}
		}
		else
		{
			p1=ContextOneState(pc);
			p1->Freq+=(p1->Freq<32);
		}
	}

	if(self->OrderFall==0)
	{
		if(!MakeRoot(self,2,NULL)) goto RESTART_MODEL;
		self->MinContext=self->MedContext=fs.Successor;
		return;
	}
	else if(--self->OrderFall==0)
	{
		Successor=fs.Successor;             SkipCount=1;
	}
	else if((Successor=NewPPMContext(&self->alloc))==NULL) goto RESTART_MODEL;

	if(!self->MaxContext->NumStats)
	{
		ContextOneState(self->MaxContext)->Symbol=fs.Symbol;
		ContextOneState(self->MaxContext)->Successor=Successor;
	}

	s0=self->MinContext->SummFreq-(ns=self->MinContext->NumStats)-(fs.Freq-1);

	for(pc=self->MedContext; pc!=self->MinContext; pc=pc->Suffix)
	{
		if((ns1=pc->NumStats)!=1)
		{
			if((ns1&1)==0)
			{
				pc->Stats=(PPMState *)ExpandUnits(&self->alloc,pc->Stats,ns1>>1);
				if(!pc->Stats) goto RESTART_MODEL;
			}
			pc->SummFreq+=(2*ns1<ns)+2*((4*ns1<=ns)&(pc->SummFreq<=8*ns1));
		}
		else
		{
			p=(PPMState *)AllocUnitsRare(&self->alloc,1);
			if(!p) goto RESTART_MODEL;
			*p=*(ContextOneState(pc));
			pc->Stats=p;

			if(p->Freq<MAX_FREQ/4-1) p->Freq+=p->Freq;
			else p->Freq=MAX_FREQ-4;

			pc->SummFreq=p->Freq+self->InitEsc+(ns>3);
		}
		cf=2*fs.Freq*(pc->SummFreq+6);
		sf=s0+pc->SummFreq;
		if(cf<6*sf)
		{
			cf=1+(cf>sf)+(cf>=4*sf);
			pc->SummFreq+=3;
		}
		else
		{
			cf=4+(cf>=9*sf)+(cf>=12*sf)+(cf>=15*sf);
			pc->SummFreq+=cf;
		}
		p=pc->Stats+ns1;
		p->Successor=Successor;
		p->Symbol=fs.Symbol;
		p->Freq=cf;
		pc->NumStats=++ns1;
	}

	if(fs.Successor)
	{
		if(!fs.Successor->NumStats&&!MakeRoot(self,SkipCount,p1)) goto RESTART_MODEL;
		self->MinContext=self->FoundState->Successor;
	}
	else
	{
		self->FoundState->Successor=Successor;
		self->OrderFall++;
	}

	self->MedContext=self->MinContext;
	self->MaxContext=Successor;
	return;

	RESTART_MODEL:
	StartModel(self);
	self->EscCount=0;
	self->PrintCount=0xFF;
}

static BOOL MakeRoot(PPMModel *self,unsigned int SkipCount,PPMState *p1)
{
	PPMContext *pc=self->MinContext,*UpBranch=self->FoundState->Successor;
	PPMState *p,*ps[MAX_O],**pps=ps;

	if(SkipCount==0)
	{
		*pps++=self->FoundState;
		if(!pc->Suffix) goto NO_LOOP;
	}
	else if(SkipCount==2) pc=pc->Suffix;

	if(p1)
	{
		p=p1;
		pc=pc->Suffix;
		goto LOOP_ENTRY;
	}

	do
	{
		pc=pc->Suffix;
		if(pc->NumStats!=1)
		{
			if((p=pc->Stats)->Symbol!=self->FoundState->Symbol)
			{
				do p++;
				while(p->Symbol!=self->FoundState->Symbol);
			}
		}
		else p=ContextOneState(pc);

		LOOP_ENTRY:
		if(p->Successor!=UpBranch)
		{
			pc=p->Successor;
			break;
		}
		*pps++=p;
	}
	while(pc->Suffix);

	NO_LOOP: 0;
	PPMState *UpState=ContextOneState(UpBranch);
	if(pc->NumStats!=1)
	{
		unsigned int cf=UpState->Symbol;
		p=pc->Stats;
		while(p->Symbol!=cf) p++;

		unsigned int s0=pc->SummFreq-pc->NumStats-(cf=p->Freq-1);
		UpState->Freq=1+((2*cf<=s0)?(5*cf>s0):((2*cf+3*s0-1)/(2*s0)));
	}
	else UpState->Freq=ContextOneState(pc)->Freq;

	while(--pps>=ps)
	{
		pc=NewPPMContextWithContext(&self->alloc,*pps,pc);
		if(!pc) return FALSE;
		*(ContextOneState(pc))=*UpState;
	}

	if(!self->OrderFall)
	{
		UpBranch->NumStats=1;
		UpBranch->Suffix=pc;
	}

	return TRUE;
}

static void ClearMask(PPMModel *self)
{
	self->EscCount=1;
	memset(self->CharMask,0,sizeof(self->CharMask));
}




// Tabulated escapes for exponential symbol distribution
static const uint8_t ExpEscape[16]={ 25,14,9,7,5,5,4,4,4,3,3,3,2,2,2,2 };

#define GET_MEAN(SUMM,SHIFT,ROUND) ((SUMM+(1<<(SHIFT-ROUND)))>>(SHIFT))

//void* operator new(size_t ) { return AllocContext(); }

PPMState *ContextOneState(PPMContext *self) { return (PPMState *)&self->SummFreq; }

static void InitPPMContext(PPMContext *self)
{
	self->NumStats=0;
	self->Suffix=NULL;
}

static void InitPPMContextWithContext(PPMContext *self,PPMState *pstats,PPMContext *shortercontext)
{
	self->NumStats=1;
	self->Suffix=shortercontext;
	pstats->Successor=self;
}

static PPMContext *NewPPMContext(PPMSubAllocator *alloc)
{
	PPMContext *context=(PPMContext *)AllocContext(alloc);
	if(context) InitPPMContext(context);
	return context;
}

static PPMContext *NewPPMContextWithContext(PPMSubAllocator *alloc,PPMState *pstats,PPMContext *shortercontext)
{
	PPMContext *context=(PPMContext *)AllocContext(alloc);
	if(context) InitPPMContextWithContext(context,pstats,shortercontext);
	return context;
}

static void DecodeBinSymbol(PPMContext *self,PPMModel *model)
{
	PPMState *rs=ContextOneState(self);
	uint16_t *bs=&model->BinSumm[rs->Freq-1][model->PrevSuccess+model->NS2BSIndx[self->Suffix->NumStats-1]];
	if(ariGetCurrentShiftCount(model,INT_BITS+PERIOD_BITS)<*bs)
	{
		model->FoundState=rs;
		rs->Freq+=(rs->Freq<128);
		model->SubRange.LowCount=0;
		model->SubRange.HighCount=*bs;
		*bs+=INTERVAL-GET_MEAN(*bs,PERIOD_BITS,2);
		model->PrevSuccess=1;
	}
	else
	{
		model->SubRange.LowCount=*bs;
		*bs-=GET_MEAN(*bs,PERIOD_BITS,2);
		model->SubRange.HighCount=BIN_SCALE;
		model->InitEsc=ExpEscape[*bs>>10];
		model->NumMasked=1;
		model->CharMask[rs->Symbol]=model->EscCount;
		model->PrevSuccess=0;
		model->FoundState=NULL;
	}
}


static void DecodeSymbol1(PPMContext *self,PPMModel *model)
{
	model->SubRange.scale=self->SummFreq;
	PPMState *p=self->Stats;
	int i,count,HiCnt;

	HiCnt=p->Freq;
	count=ariGetCurrentCount(model);

	if(count<HiCnt)
	{
		model->SubRange.HighCount=HiCnt;
		model->PrevSuccess=(2*HiCnt>model->SubRange.scale);

		HiCnt+=4;
		model->FoundState=p;
		p->Freq=HiCnt;
		self->SummFreq+=4;

		if(HiCnt>MAX_FREQ) RescaleContext(self,model);
		model->SubRange.LowCount=0;

		return;
	}

	model->PrevSuccess=0;
	i=self->NumStats-1;
	while((HiCnt+=(++p)->Freq)<=count)
	{
		if(--i==0)
		{
			model->SubRange.LowCount=HiCnt;
			model->CharMask[p->Symbol]=model->EscCount;
			model->NumMasked=self->NumStats;
			model->FoundState=NULL;
			i=self->NumStats-1;

			do model->CharMask[(--p)->Symbol]=model->EscCount;
			while(--i);

			model->SubRange.HighCount=model->SubRange.scale;
			return;
		}
	}

	model->SubRange.LowCount=(model->SubRange.HighCount=HiCnt)-p->Freq;

	UpdateContext1(self,model,p);
}

static void UpdateContext1(PPMContext *self,PPMModel *model,PPMState *p)
{
	model->FoundState=p;
	p->Freq+=4;
	self->SummFreq+=4;

	if(p[0].Freq>p[-1].Freq)
	{
		SWAP(p[0],p[-1]);
		model->FoundState=--p;
		if(p->Freq>MAX_FREQ) RescaleContext(self,model);
	}
}



static void DecodeSymbol2(PPMContext *self,PPMModel *model)
{
	int count,HiCnt,i=self->NumStats-model->NumMasked;
	SEE2Context *psee2c=MakeEscFreq2(self,model,i);
	PPMState *ps[256],**pps=ps,*p=self->Stats-1;

	HiCnt=0;

	do
	{
		do p++;
		while(model->CharMask[p->Symbol]==model->EscCount);

		HiCnt+=p->Freq;
		*pps++=p;
	}
	while(--i);

	model->SubRange.scale+=HiCnt;
	count=ariGetCurrentCount(model);
	p=*(pps=ps);

	if(count<HiCnt)
	{
		HiCnt=0;
		while((HiCnt+=p->Freq)<=count) p=*++pps;

		model->SubRange.LowCount=(model->SubRange.HighCount=HiCnt)-p->Freq;
		UpdateSEE2(psee2c);
		UpdateContext2(self,model,p);
	}
	else
	{
		model->SubRange.LowCount=HiCnt;
		model->SubRange.HighCount=model->SubRange.scale;
		i=self->NumStats-model->NumMasked;
		pps--;

		do model->CharMask[(*++pps)->Symbol]=model->EscCount;
		while(--i);

		psee2c->Summ+=model->SubRange.scale;
		model->NumMasked=self->NumStats;
	}
}

static SEE2Context *MakeEscFreq2(PPMContext *self,PPMModel *model,int Diff)
{
	SEE2Context *psee2c;

	if(self->NumStats!=256)
	{
		psee2c=&model->SEE2Cont[model->NS2Indx[Diff-1]][
		+(Diff<self->Suffix->NumStats-self->NumStats)
		+2*(self->SummFreq<11*self->NumStats)
		+4*(model->NumMasked>Diff)];

		model->SubRange.scale=GetSEE2Mean(psee2c);
	}
	else
	{
		psee2c=&model->SEE2Cont[43][0];
		model->SubRange.scale=1;
	}

	return psee2c;
}

static void UpdateContext2(PPMContext *self,PPMModel *model,PPMState *p)
{
	model->FoundState=p;
	p->Freq+=4;
	self->SummFreq+=4;
	if(p->Freq>MAX_FREQ) RescaleContext(self,model);
	model->EscCount++;
}

static void RescaleContext(PPMContext *self,PPMModel *model)
{
	int OldNS=self->NumStats,i=self->NumStats-1;
	PPMState *p=model->FoundState;

	while(p!=self->Stats) { SWAP(p[0],p[-1]); p--; }

	self->Stats[0].Freq+=4;
	self->SummFreq+=4;

	int EscFreq=self->SummFreq-p->Freq;
	int Adder=(model->OrderFall!=0);

	p->Freq=(p->Freq+Adder)>>1;
	self->SummFreq=p->Freq;

	do
	{
		p++;
		EscFreq-=p->Freq;
		self->SummFreq+=(p->Freq=(p->Freq+Adder)>>1);
		if(p[0].Freq>p[-1].Freq)
		{
			PPMState tmp=*p;
			PPMState *p1=p;

			do p1[0]=p1[-1];
			while(--p1!=self->Stats&&tmp.Freq>p1[-1].Freq);
			*p1=tmp;
		}
	}
	while(--i);

	if(p->Freq==0)
	{
		do i++;
		while((--p)->Freq==0);

		EscFreq+=i;

		self->NumStats-=i;
		if(self->NumStats==1)
		{
			PPMState tmp=self->Stats[0];
			do
			{
				tmp.Freq-=(tmp.Freq>>1);
				EscFreq>>=1;
			}
			while(EscFreq>1);

			FreeUnits(&model->alloc,self->Stats,(OldNS+1)>>1);
			model->FoundState=ContextOneState(self);
			*(ContextOneState(self))=tmp;

			return;
		}
	}
	EscFreq-=(EscFreq>>1);
	self->SummFreq+=EscFreq;

	int n0=(OldNS+1)>>1,n1=(self->NumStats+1)>>1;
	if(n0!=n1) self->Stats=(PPMState *)ShrinkUnits(&model->alloc,self->Stats,n0,n1);

	model->FoundState=self->Stats;
}

@end
