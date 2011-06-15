#include "Decompressor.h"
#include "LZMA.h"

#include <stdlib.h>




// Helper functions for reading from the input stream.
static int FullRead(WinZipJPEGDecompressor *self,uint8_t *buffer,size_t length);
static int SkipBytes(WinZipJPEGDecompressor *self,size_t length);

// Little endian integer parsing functions.
static inline uint16_t LittleEndianUInt16(uint8_t *ptr) { return ptr[0]|(ptr[1]<<8); }
static inline uint32_t LittleEndianUInt32(uint8_t *ptr) { return ptr[0]|(ptr[1]<<8)|(ptr[2]<<16)|(ptr[3]<<24); }

// Allocator functions for LZMA.
static void *Alloc(void *p,size_t size) { return malloc(size); }
static void Free(void *p,void *address) { return free(address); }
static ISzAlloc lzmaallocator={Alloc,Free};



WinZipJPEGDecompressor *AllocWinZipJPEGDecompressor(WinZipJPEGReadFunction *readfunc,void *inputcontext)
{
	WinZipJPEGDecompressor *self=malloc(sizeof(WinZipJPEGDecompressor));
	if(!self) return NULL;

	self->readfunc=readfunc;
	self->inputcontext=inputcontext;

	self->metadatalength=0;
	self->metadatabytes=NULL;
	self->isfinalbundle=false;
}

void FreeWinZipJPEGDecompressor(WinZipJPEGDecompressor *self)
{
	if(!self) return;

	free(self->metadatabytes);
	free(self);
}




int ReadWinZipJPEGHeader(WinZipJPEGDecompressor *self)
{
	// Read 4-byte header.
	uint8_t header[4];
	int error=FullRead(self,header,sizeof(header));
	if(error) return error;

	// Sanity check the header, and make sure it contains only versions we can handle.
	if(header[0]<4) return WinZipJPEGInvalidHeaderError;
	if(header[1]!=0x10) return WinZipJPEGInvalidHeaderError;
	if(header[2]!=0x01) return WinZipJPEGInvalidHeaderError;
	if(header[3]&0xe0) return WinZipJPEGInvalidHeaderError;

	// The header can possibly be bigger than 4 bytes, so skip the rest.
	// (Unlikely to happen).
	if(header[0]>4)
	{
		int error=SkipBytes(self,header[0]-4);
		if(error) return error;
	}

	// Parse slice value.
	self->slicevalue=header[3]&0x1f;

	return WinZipJPEGNoError;
}

int ReadNextWinZipJPEGBundle(WinZipJPEGDecompressor *self)
{
	// Free and clear any old metadata.
	free(self->metadatabytes);
	self->metadatalength=0;
	self->metadatabytes=NULL;

	// Read bundle header.
	uint8_t header[4];
	int error=FullRead(self,header,sizeof(header));
	if(error) return error;

	// Parse metadata sizes from header.
	uint32_t uncompressedsize=LittleEndianUInt16(&header[0]);
	uint32_t compressedsize=LittleEndianUInt16(&header[2]);

	// If the sizes do not fit in 16 bits, both are set to 0xffff and
	// an 8-byte 32-bit header is appended.
	if(uncompressedsize==0xffff && compressedsize==0xffff)
	{
		uint8_t header[8];
		int error=FullRead(self,header,sizeof(header));
		if(error) return error;

		uncompressedsize=LittleEndianUInt32(&header[0]);
		compressedsize=LittleEndianUInt32(&header[4]);
	}

	// Allocate space for the uncompressed metadata.
	self->metadatabytes=malloc(uncompressedsize);
	if(!self->metadatabytes) return WinZipJPEGOutOfMemoryError;
	self->metadatalength=uncompressedsize;

	// Allocate temporary space for the compressed metadata, and read it.
	uint8_t *compressedbytes=malloc(compressedsize);
	if(!compressedbytes) return WinZipJPEGOutOfMemoryError;

	error=FullRead(self,compressedbytes,compressedsize);
	if(error) { free(compressedbytes); return error; }

	// Calculate the dictionary size used for the LZMA coding.
	int dictionarysize=(uncompressedsize+511)&~511;
	if(dictionarysize<1024) dictionarysize=1024; // Silly - LZMA enforces a lower limit of 4096.
	if(dictionarysize>512*1024) dictionarysize=512*1024;

	// Create properties chunk for LZMA, using the dictionary size and default settings (lc=3, lp=0, pb=2).
	uint8_t properties[5]={3+0*9+2*5*9,dictionarysize,dictionarysize>>8,dictionarysize>>16,dictionarysize>>24};

	// Run LZMA decompressor.
	SizeT destlen=uncompressedsize,srclen=compressedsize;
	ELzmaStatus status;
	SRes res=LzmaDecode(self->metadatabytes,&destlen,compressedbytes,&srclen,
	properties,sizeof(properties),LZMA_FINISH_END,&status,&lzmaallocator);

	// Free temporary buffer.
	free(compressedbytes);

	// Check if LZMA decoding succeeded.
	if(res!=SZ_OK) return WinZipJPEGLZMAError;

	// Initialize arithmetic coder for reading scans.
	InitializeWinZipJPEGArithmeticDecoder(&self->decoder,self->readfunc,self->inputcontext);

	return WinZipJPEGNoError;
}



// Helper function that makes sure to read as much data as requested, even
// if the read function returns short buffers, and reports an error if it
// reaches EOF prematurely.
static int FullRead(WinZipJPEGDecompressor *self,uint8_t *buffer,size_t length)
{
	size_t totalread=0;
	while(totalread<length)
	{
		size_t actual=self->readfunc(self->inputcontext,&buffer[totalread],length-totalread);
		if(actual==0) return WinZipJPEGEndOfStreamError;
		totalread+=actual;
	}

	return WinZipJPEGNoError;
}

// Helper function to skip data by reading and discarding.
static int SkipBytes(WinZipJPEGDecompressor *self,size_t length)
{
	uint8_t buffer[1024];

	size_t totalread=0;
	while(totalread<length)
	{
		size_t numbytes=length-totalread;
		if(numbytes>sizeof(buffer)) numbytes=sizeof(buffer);
		size_t actual=self->readfunc(self->inputcontext,buffer,numbytes);
		if(actual==0) return WinZipJPEGEndOfStreamError;
		totalread+=actual;
	}

	return WinZipJPEGNoError;
}

