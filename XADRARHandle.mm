#import "XADRARHandle.h"
#import "unrar/rar.hpp"

@implementation XADRARHandle

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length version:(int)version
{
	if(self=[super initWithName:[handle name] length:length])
	{
		sourcehandle=[handle retain];
		startoffs=[handle offsetInFile];
		method=version;
		ioptr=unpackptr=0;
	}
	return self;
}

-(void)dealloc
{
	if(ioptr) delete (ComprDataIO *)ioptr;
	if(unpackptr) delete (Unpack *)unpackptr;

	[sourcehandle release];
	[super dealloc];
}

-(void)resetBlockStream
{
	[sourcehandle seekToFileOffset:startoffs];

	if(ioptr) delete (ComprDataIO *)ioptr;
	if(unpackptr) delete (Unpack *)unpackptr;
	ioptr=(void *)new ComprDataIO((void *)self);
	unpackptr=(void *)new Unpack((ComprDataIO *)ioptr);

	((Unpack *)unpackptr)->Init(NULL);

	((Unpack *)unpackptr)->SetDestSize(streamlength);
}

-(int)produceBlockAtOffset:(off_t)pos
{
	Unpack *unpack=(Unpack *)unpackptr;

	blocklength=-1;
	unpack->DoUnpack(method,false); // solid);

	return blocklength;
}

-(CSHandle *)sourceHandle { return sourcehandle; }

-(void)receiveBlock:(void *)block length:(int)length
{
	Unpack *unpack=(Unpack *)unpackptr;
	unpack->SetSuspended(true);

	[self setBlockPointer:(uint8_t *)block];
	blocklength=length;
}

@end

ErrorHandler ErrHandler;

void ErrorHandler::MemoryError() { /*throw XADERR_NOMEMORY;*/ }

ComprDataIO::ComprDataIO(void *handle)
{
	this->handle=handle;
}

int ComprDataIO::UnpRead(byte *Addr,uint Count)
{
	return [[(XADRARHandle *)handle sourceHandle] readAtMost:Count toBuffer:Addr];
}

void ComprDataIO::UnpWrite(byte *Addr,uint Count)
{
//	if(dryrun) return;
	[(XADRARHandle *)handle receiveBlock:Addr length:Count];
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



/*extern "C" xadPTR rar_make_unpacker(struct xadArchiveInfo *ai,struct xadMasterBase *xadMasterBase)
{
	RarCppPrivate *unpacker=new RarCppPrivate;
	if(!unpacker) return NULL;

	unpacker->io=new ComprDataIO(ai,xadMasterBase);
	unpacker->unpack=new Unpack(unpacker->io);

	if(!unpacker->io||!unpacker->unpack) { delete unpacker->unpack; delete unpacker->io; delete unpacker; return NULL; }

	try { unpacker->unpack->Init(NULL); }
	catch(xadERROR error) { delete unpacker->unpack; delete unpacker->io; delete unpacker; return NULL; }

	return (xadPTR)unpacker;
}

extern "C" xadERROR rar_run_unpacker(xadPTR *unpacker,xadSize packedsize,xadSize fullsize,xadUINT8 version,xadBOOL solid,xadBOOL dryrun,xadUINT32 *crc)
{
	Unpack *unp=((RarCppPrivate *)unpacker)->unpack;
	ComprDataIO *io=((RarCppPrivate *)unpacker)->io;

	io->bytesleft=packedsize;
	io->crcptr=crc;
	io->dryrun=dryrun;

	unp->SetDestSize(fullsize);

	try { unp->DoUnpack(version,solid); }
	catch(xadERROR err) { return err; }

	return XADERR_OK;
}

extern "C" void rar_destroy_unpacker(xadPTR *unpacker)
{
	if(unpacker)
	{
		delete ((RarCppPrivate *)unpacker)->unpack;
		delete ((RarCppPrivate *)unpacker)->io;
		delete (RarCppPrivate *)unpacker;
	}
}
*/
