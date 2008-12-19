#include "RARUnpacker.h"
#include "unrar/rar.hpp"


extern "C" {

RARUnpacker *AllocRARUnpacker(RARReadFunc readfunc,void *readparam1,void *readparam2)
{
	RARUnpacker *self=(RARUnpacker *)malloc(sizeof(RARUnpacker));
	if(!self) return NULL;

	ComprDataIO *io=new ComprDataIO(self);
	Unpack *unpack=new Unpack(io);
	unpack->Init(NULL);

	self->io=(void *)io;
	self->unpack=(void *)unpack;

	self->readfunc=readfunc;
	self->readparam1=readparam1;
	self->readparam2=readparam2;

	return self;
}

void FreeRARUnpacker(RARUnpacker *self)
{
	delete (Unpack *)self->unpack;
	delete (ComprDataIO *)self->io;
	free(self);
}

void StartRARUnpacker(RARUnpacker *self,off_t length,int method,int solid)
{
	Unpack *unpack=(Unpack *)self->unpack;
	unpack->SetDestSize(length);
	unpack->SetSuspended(false);
	self->method=method;
	self->solid=solid;
}

void *NextRARBlock(RARUnpacker *self,int *length)
{
	Unpack *unpack=(Unpack *)self->unpack;

	self->blocklength=-1;
	unpack->DoUnpack(self->method,self->solid);
	*length=self->blocklength;

	return self->blockbytes;
}

int IsRARFinished(RARUnpacker *self)
{
	Unpack *unpack=(Unpack *)self->unpack;
	return unpack->IsFileExtracted();
}

}


ComprDataIO::ComprDataIO(RARUnpacker *unpacker)
{
	this->unpacker=unpacker;
}

int ComprDataIO::UnpRead(byte *Addr,uint Count)
{
	return unpacker->readfunc(unpacker->readparam1,unpacker->readparam2,Count,Addr);
}

void ComprDataIO::UnpWrite(byte *Addr,uint Count)
{
	Unpack *unpack=(Unpack *)unpacker->unpack;
	unpack->SetSuspended(true);

	unpacker->blockbytes=Addr;
	unpacker->blocklength=Count;
}



uint CRC(uint StartCRC,const void *Addr,uint Size)
{
	static uint CRCTab[256]={0};
	if (CRCTab[1]==0)
	{
		for (int I=0;I<256;I++)
		{
			uint C=I;
			for (int J=0;J<8;J++) C=(C & 1) ? (C>>1)^0xEDB88320L : (C>>1);
			CRCTab[I]=C;
		}
	}
	byte *Data=(byte *)Addr;
	for (int I=0;I<Size;I++) StartCRC=CRCTab[(byte)(StartCRC^Data[I])]^(StartCRC>>8);
	return(StartCRC);
}

ErrorHandler ErrHandler;

void ErrorHandler::MemoryError() { /*throw XADERR_NOMEMORY;*/ }

