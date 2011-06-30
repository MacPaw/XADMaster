#include "Decompressor.h"
#include "LZMA.h"

#include <stdlib.h>




// Helper functions for reading from the input stream.
static int FullRead(WinZipJPEGDecompressor *self,uint8_t *buffer,size_t length);
static int SkipBytes(WinZipJPEGDecompressor *self,size_t length);

// JPEG parser.
static bool ParseJPEG(WinZipJPEGDecompressor *self);

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

	self->hasparsedjpeg=false;
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

	// If this is the first bundle, parse JPEG structure
	if(!self->hasparsedjpeg)
	{
		if(!ParseJPEG(self)) return WinZipJPEGParseError;
		self->hasparsedjpeg=true;
	}

	// Initialize arithmetic coder for reading scans.
	InitializeWinZipJPEGArithmeticDecoder(&self->decoder,self->readfunc,self->inputcontext);

	// Initialize arithmetic coder contexts.
	// ...

	return WinZipJPEGNoError;
}


static inline unsigned int Category(uint16_t val)
{
	unsigned int cat=0;
	if(val&0xff00) { val>>=8; cat|=8; }
	if(val&0xf0) { val>>=4; cat|=4; }
	if(val&0xc) { val>>=2; cat|=2; }
	if(val&0x2) { val>>=1; cat|=1; }
	return cat;
}

void TestDecompress(WinZipJPEGDecompressor *self)
{
/*	int slicesize;

	if(self->slicevalue)
	{
		int pow2size=1<<(self->slicevalue+
		slicesize=ceil(self->height/ceil(self->height/max(pow2size/self->width,1)))*self->width;
	}
	else
	{
		slicesize=(self->width+7)/8*(self->height+7)/8;
	}*/

	for(int comp=0;comp<self->numscancomponents;comp++)
	{


eobbins[4][12][64];
zerobins[4][62*6*3];
pivotbins[4][63*5*7]; // Why 63?
magnitudebins[4][3*9*9*9];
remainderbins[4][13][3*7];

static void DecodeMCU(WinZipJPEGDecompressor *self,int x,int y
int16_t *current[64],int16_t *west[64],int16_t *north[64])
{
	// Decode End Of Block value to find out how many AC components there are. (5.6.5)

	// Calculate EOB context. (5.6.5.2)
	int average;
	if(x==0&&y==0) average=0;
	if(x==0) average=Sum(north,0); 
	else if(y==0) average=Sum(west,0);
	else average=(Sum(north,0)+Sum(west,0)+1)/2;

	int eobcontext=Min(Category(average),12);

	// Decode EOB bits using binary tree. (5.6.5.1)
	unsigned int bitstring=1;
	for(int i=0;i<6;i++)
	{
		bitstring|=(bitstring<<1)|NextBitFromWinZipJPEGArithmeticDecoder(&self->decoder,
		self->eobbins[comp][eobcontext][bitstring]);
	}
	unsigned int eob=bitstring&0x3f;

	// Decode AC components, if any. (5.6.6)
	for(int k=1;k<=eob;k++)
	{
		DecodeACComponent(self,k,current,west,north);
	}

	// Fill out remaining block entries with 0.
	for(int k=eob+1;k<=63;k++) current[k]=0;

	// Decode DC components. (5.6.7)
}

static int DecodeACComponent(WinZipJPEGDecompressor *self,int k,
int16_t *current[64],int16_t *west[64],int16_t *north[64])
{
	// Decode zero/non-zero bit. (5.6.6.1)
	int val1;
	if(IsFirstRowOrColumn(k)) val1=Abs(BDR(current,north,west,k);
	else val1=Average(current,k);

	int val2=Sum(current,k);

	int zerocontext=((k-1)*3+Min(Category(val1),2))*6+min(Category(val2),5);
	int nonzero=NextBitFromWinZipJPEGArithmeticDecoder(&self->decoder,
	&self->zerobins[comp][zerocontext]);

	// If this component is zero, there is no need to decode further parameters.
	if(!nonzero) return 0;

	// This component is not zero. Proceed with decoding absolute value.
	int absvalue;

	// Decode pivot (abs>=2). (5.6.6.2)
	int pivotcontext=((k-1)*5+Min(Category(val1),4))*7+min(Category(val2),6);
	int pivot=NextBitFromWinZipJPEGArithmeticDecoder(&self->decoder,
	&self->pivotbins[comp][pivotcontext]);

	if(!pivot)
	{
		// The absolute of this component is not >=2. It must therefore be 1,
		// and there is no need to decode the value.
		absvalue=1;
	}
	else
	{
		// The absolute of this component is >=2. Proceed with decoding
		// the absolute value. (5.6.6.3)
		int val3,n;
		if(IsFirstRow(k)) { val3=Column(k)-1; n=0; }
		else if(IsFirstColumn(k)) { val3=Row(k)-1; n=1; }
		else { val3=Category(k-4); n=2; }

		int magnitudecontext=(n*9+Min(Category(val1),8))*9+Min(Category(val2),8);
		int remaindercontext=n*7+val3;

		// Decode binarization. (5.6.4)
		...
	}

	// Decode sign. (5.6.6.4)
	int sign;
	if(IsFirstOrSecondRowOrColumn(k))
	{
		// Calculate sign context. (5.6.6.4.1)
		int signcontext;
		...
		sign=NextBitFromWinZipJPEGArithmeticDecoder(&self->decoder,signcontext);
	}
	else
	{
		// Use fixed probability.
		sign=NextBitFromWinZipJPEGArithmeticDecoder(&self->decoder,&self->fixedcontext);
	}

	if(sign) return -absvalue;
	else return absvalue;
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



// JPEG parser.
#include <stdio.h>
static uint8_t *FindStartOfImage(uint8_t *ptr,uint8_t *end);
static uint8_t *FindNextMarker(uint8_t *ptr,uint8_t *end);
static int ParseSize(uint8_t *ptr,uint8_t *end);

static inline uint16_t ParseUInt16(uint8_t *ptr) { return (ptr[0]<<8)|ptr[1]; }

static bool ParseJPEG(WinZipJPEGDecompressor *self)
{
	self->restartinterval=0;

	uint8_t *ptr=self->metadatabytes;
	uint8_t *end=self->metadatabytes+self->metadatalength;

	ptr=FindStartOfImage(ptr,end);
	if(!ptr) return false;

	for(;;)
	{
		ptr=FindNextMarker(ptr,end);
		if(!ptr) return false;

		switch(*ptr++)
		{
			case 0xd8: // Start of image
fprintf(stderr,"Start of image\n");
				// Empty marker, do nothing.
			break;

			case 0xc4: // Define huffman table
			{
				int size=ParseSize(ptr,end);
				if(!size) return false;
				uint8_t *next=ptr+size;

				ptr+=2;

fprintf(stderr,"Define huffman table(s)\n");
				while(ptr+17<=next)
				{
					int class=*ptr>>4;
					int index=*ptr&0x0f;
					ptr++;

					if(class!=0 && class!=1) return false;
					if(index>=4) return false;

					int numcodes[16];
					int totalcodes=0;
					for(int i=0;i<16;i++)
					{
						numcodes[i]=ptr[i];
						totalcodes+=numcodes[i];
					}
					ptr+=16;

					if(ptr+totalcodes>next) return false;

fprintf(stderr," > %s table at %d with %d codes\n",class==0?"DC":"AC",index,totalcodes);

					for(int i=0;i<16;i++)
					{
						for(int j=0;j<numcodes[i];j++)
						{
							int value=*ptr++;
							self->huffmantables[class][index][value].length=i+1;
						}
					}
				}

				ptr=next;
			}
			break;

			case 0xdb: // Define quantization table(s)
			{
				int size=ParseSize(ptr,end);
				if(!size) return false;
				uint8_t *next=ptr+size;

				ptr+=2;

fprintf(stderr,"Define quantization table(s)\n");
				while(ptr+1<=next)
				{
					int precision=*ptr>>4;
					int index=*ptr&0x0f;
					ptr++;

					if(index>=4) return false;

					if(precision==0)
					{
fprintf(stderr," > 8 bit table at %d\n",index);
						if(ptr+64>next) return false;
						for(int i=0;i<64;i++) self->quantizationtables[index][i]=ptr[i];
						ptr+=64;
					}
					else if(precision==1)
					{
fprintf(stderr," > 16 bit table at %d\n",index);
						if(ptr+128>next) return false;
						for(int i=0;i<64;i++) self->quantizationtables[index][i]=ParseUInt16(&ptr[2*i]);
						ptr+=128;
					}
					else return false;
				}

				ptr=next;
			}
			break;

			case 0xdd: // Define restart interval
			{
				int size=ParseSize(ptr,end);
				if(!size) return false;
				uint8_t *next=ptr+size;

				self->restartinterval=ParseUInt16(&ptr[2]);

				ptr=next;
fprintf(stderr,"Define restart interval: %d\n",self->restartinterval);
			}
			break;

			case 0xc0: // Start of frame 0
			case 0xc1: // Start of frame 1
			{
				int size=ParseSize(ptr,end);
				if(!size) return false;
				uint8_t *next=ptr+size;

				if(size<8) return false;
				self->bits=ptr[2];
				self->height=ParseUInt16(&ptr[3]);
				self->width=ParseUInt16(&ptr[5]);
				self->numcomponents=ptr[7];

				if(self->numcomponents<1 || self->numcomponents>4) return false;
				if(size<8+self->numcomponents*3) return false;

				for(int i=0;i<self->numcomponents;i++)
				{
					self->components[i].identifier=ptr[8+i*3];
					self->components[i].horizontalfactor=ptr[9+i*3]>>4;
					self->components[i].verticalfactor=ptr[9+i*3]&0x0f;
					self->components[i].quantizationtable=ptr[10+i*3];
				}
fprintf(stderr,"Start of frame: %dx%d %d bits %d comps\n",self->width,self->height,self->bits,self->numcomponents);

				ptr=next;
			}
			break;

			case 0xda: // Start of scan
			{
				int size=ParseSize(ptr,end);
				if(!size) return false;

				if(size<6) return false;

				self->numscancomponents=ptr[2];
				if(self->numscancomponents<1 || self->numscancomponents>4) return false;
				if(size<6+self->numscancomponents*2) return false;

				for(int i=0;i<self->numscancomponents;i++)
				{
					int identifier=ptr[3+i*2];
					int index=-1;
					for(int j=0;j<self->numcomponents;j++)
					{
						if(self->components[j].identifier==identifier)
						{
							index=j;
							break;
						}
					}
					if(index==-1) return false;

					self->scancomponents[i].componentindex=index;

					self->scancomponents[i].dctable=ptr[4+i*2]>>4;
					self->scancomponents[i].actable=ptr[4+i*2]&0x0f;
				}

				if(ptr[3+self->numscancomponents*2]!=0) return false;
				if(ptr[4+self->numscancomponents*2]!=63) return false;
				if(ptr[5+self->numscancomponents*2]!=0) return false;

fprintf(stderr,"Start of scan: %d comps\n",self->numscancomponents,ptr[3+self->numscancomponents*2]);

				return true;
			}
			break;


			case 0xd9: // End of image
				return true; // TODO: figure out how to properly find end of file.

			default:
			{
fprintf(stderr,"Unknown marker %02x\n",ptr[-1]);
				int size=ParseSize(ptr,end);
				if(!size) return false;
				ptr+=size;
			}
			break;
		}
	}
}

// Find start of image marker.
static uint8_t *FindStartOfImage(uint8_t *ptr,uint8_t *end)
{
	while(ptr+2<=end)
	{
		if(ptr[0]==0xff && ptr[1]==0xd8) return ptr;
		ptr++;
	}

	return NULL;
}

// Find next marker, skipping pad bytes.
static uint8_t *FindNextMarker(uint8_t *ptr,uint8_t *end)
{
	if(ptr>=end) return NULL;
	if(*ptr!=0xff) return NULL;

	while(*ptr==0xff)
	{
		ptr++;
		if(ptr>=end) return NULL;
	}

	return ptr;
}

// Parse and sanity check the size of a marker.
static int ParseSize(uint8_t *ptr,uint8_t *end)
{
	if(ptr+2>end) return 0;

	int size=ParseUInt16(ptr);
	if(size<2) return 0;
	if(ptr+size>end) return 0;

	return size;
}

