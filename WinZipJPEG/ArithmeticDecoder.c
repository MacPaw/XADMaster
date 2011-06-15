#include "ArithmeticDecoder.h"

static void LogDecoder(WinZipJPEGArithmeticDecoder *self);
static void ChangeState(WinZipJPEGArithmeticDecoder *self);
static void UpdateMPS(WinZipJPEGArithmeticDecoder *self);
static void QSmaller(WinZipJPEGArithmeticDecoder *self);
static void AntilogX(WinZipJPEGArithmeticDecoder *self);
static void UpdateLPS(WinZipJPEGArithmeticDecoder *self);
static void QBigger(WinZipJPEGArithmeticDecoder *self);
static void IncrIndex(WinZipJPEGArithmeticDecoder *self);
static void DblIndex(WinZipJPEGArithmeticDecoder *self);
static void SwitchMPS(WinZipJPEGArithmeticDecoder *self);
static void LogX(WinZipJPEGArithmeticDecoder *self);
static void Renorm(WinZipJPEGArithmeticDecoder *self);
static void ByteIn(WinZipJPEGArithmeticDecoder *self);
static void UpdateLRT(WinZipJPEGArithmeticDecoder *self);
static void LRMBig(WinZipJPEGArithmeticDecoder *self);
static void InitDec(WinZipJPEGArithmeticDecoder *self);
static void Flush(WinZipJPEGArithmeticDecoder *self);

void InitializeWinZipJPEGArithmeticDecoder(WinZipJPEGArithmeticDecoder *self,WinZipJPEGReadFunction *readfunc, void *inputcontext)
{
	self->readfunc=readfunc;
	self->inputcontext=inputcontext;

	InitDec(self);
}

int NextBitFromWinZipJPEGArithmeticDecoder(WinZipJPEGArithmeticDecoder *self,int state)
{
	self->s=state;
	LogDecoder(self);
	return self->yn;
}

static void LogDecoder(WinZipJPEGArithmeticDecoder *self)
{
	if(self->s!=self->ns)
	{
		ChangeState(self);
		UpdateLRT(self);
	}

	self->lr=self->lr+self->lp;
	self->yn=self->mps;

	if(self->lr>=self->lrt)
	{
		if(self->lx>self->lr)
		{
			UpdateMPS(self);
		}
		else
		{
			self->dlrm=self->lrm-self->lr;
			Renorm(self);
			if(self->lx>self->lr)
			{
				self->lrm=self->dlrm+self->lr;
				if(self->lr>=self->lrm) UpdateMPS(self);
			}
			else
			{
				self->k++;
				self->yn=1^self->yn;
				AntilogX(self);
				self->x=self->x-self->dx;
				LogX(self);
				UpdateLPS(self);
				self->lrm=self->dlrm+self->lr;
			}
		}
		UpdateLRT(self);
	}
}

static void ChangeState(WinZipJPEGArithmeticDecoder *self)
{
	self->dlrst[self->s]=self->lrm-self->lr;
	self->s=self->ns;
	self->k=self->kst[self->s];
	self->i=self->ist[self->s];
	self->mps=self->mpsst[self->s];
	self->lp=self->logp[self->i];
	self->lrm=self->lr+self->dlrst[self->s];
	LRMBig(self);
}

static void UpdateMPS(WinZipJPEGArithmeticDecoder *self)
{
	if(self->k<=self->kmin) QSmaller(self);
	self->k=0;
	self->kst[self->s]=0;
	self->lrm=self->lr+self->nmaxlp[self->i];
	LRMBig(self);
}

static void QSmaller(WinZipJPEGArithmeticDecoder *self)
{
	self->i++;
	if(self->logp[self->i]==0)
	{
		self->i--;
	}
	else
	{
		if(self->k<=self->kmin1)
		{
			self->i=self->i+self->halfi[self->i];

			if(self->k<=self->kmin2)
			{
				self->i=self->i+self->halfi[self->i];
			}
		}
		self->ist[self->s]=self->i;
		self->lp=self->logp[self->i];
	}
}

static void AntilogX(WinZipJPEGArithmeticDecoder *self)
{
	self->mr=self->lr&0x3ff;
	self->dx=self->alogtbl[self->mr];
	self->ct=self->lr>>10; // logical shift
	self->ct=7-self->ct;
	self->dx=self->dx<<self->ct;
}

static void UpdateLPS(WinZipJPEGArithmeticDecoder *self)
{
	self->lr=self->lr+self->lqp[self->i];

	if(self->k>=self->kmax)
	{
		QBigger(self);
		self->k=0;
		self->dlrm=self->nmaxlp[self->i];
		self->lp=self->logp[self->i];
		self->ist[self->s]=self->i;
	}
	else
	{
		if(self->dlrm<0) self->dlrm=0;
	}

	self->kst[self->s]=self->k;
}


static void QBigger(WinZipJPEGArithmeticDecoder *self)
{
	self->incrsv=0;

	if(self->dlrm>=self->nmaxlp[self->i]/2)
	{
		self->dlrm=self->nmaxlp[self->i]-self->dlrm;
		if(self->dlrm<=self->nmaxlp[self->i]/4) DblIndex(self);
		DblIndex(self);
	}
	else
	{
		if(self->dlrm>=self->nmaxlp[self->i]/4) IncrIndex(self);
		IncrIndex(self);
	}

	SwitchMPS(self);
	self->lp=self->logp[self->i];
}


static void IncrIndex(WinZipJPEGArithmeticDecoder *self)
{
	if(self->i>0) self->i--;
	else self->incrsv++;
}

static void DblIndex(WinZipJPEGArithmeticDecoder *self)
{
	if(self->i>0) self->i=self->i-self->dbli[self->i];
	else self->incrsv=self->incrsv+self->dbli[self->i];
}

static void SwitchMPS(WinZipJPEGArithmeticDecoder *self)
{
	if(self->i<=0)
	{
		self->i=0;
		self->mps=1^self->mps;
		self->mpsst[self->s]=self->mps;
		self->i=self->i+self->incrsv;
	}
}

static void LogX(WinZipJPEGArithmeticDecoder *self)
{
	self->cx=self->x>>12; // logical shift
	if(self->cx==0)
	{
		self->lx=0x2000;
	}
	else
	{
		self->cx=self->chartbl[self->cx];
		self->ct=8-self->cx;
		self->xf=0xfff&(self->x>>self->ct); // logical shift
		self->lx=self->cx<<10;
		self->lx=self->lx-self->logtbl[self->xf];
	}
}

static void Renorm(WinZipJPEGArithmeticDecoder *self)
{
	if(self->lr>0x1fff)
	{
		do
		{
			if(self->b==0xff)
			{
				if(self->b0==0xff)
				{
					ByteIn(self);
					self->x=self->x+self->b;
				}
			}
			ByteIn(self);
			self->x=self->x<<8;
			self->x=self->x+self->b;
			self->lr=self->lr-0x2000;
		}
		while(self->lr>0x1fff);
	}

	LogX(self);
}

static void ByteIn(WinZipJPEGArithmeticDecoder *self)
{
	self->b0=self->b;
	self->readfunc(self->inputcontext,&self->b,1);
//	self->b=Stuff;
}

static void UpdateLRT(WinZipJPEGArithmeticDecoder *self)
{
	self->lrt=self->lrm;
	if(self->lrt>self->lx) self->lrt=self->lx;
}

static void LRMBig(WinZipJPEGArithmeticDecoder *self)
{
	if(self->lrm>0x7ff)
	{
		self->dlrm=self->lrm-self->lr;
		Renorm(self);
		self->lrm=self->dlrm+self->lr;
	}
}

static void InitDec(WinZipJPEGArithmeticDecoder *self)
{
	//InitializeTables(self);
	self->s=42222; // TODO: fix

	ByteIn(self);
	self->x=self->b;
	ByteIn(self);
	self->x=self->x<<8;
	self->x=self->x+self->b;

	self->lr=0x1001;
	self->lrm=self->lr;
	LogX(self);

	if(self->x==0xffff) ByteIn(self);
}

/*static void Flush(WinZipJPEGArithmeticDecoder *self)
{
	Renorm(self);
	self->lr=self->lr+0x8000;
	Renorm(self);
	//if(self->bp>=self->be-2) BufOut(self);
	//if(self->bp>=self->bpst) BufOut(self);
}*/


