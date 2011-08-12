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

// Decoder functions.

static void DecodeMCU(WinZipJPEGDecompressor *self,int comp,int x,int y,
int16_t current[64],int16_t west[64],int16_t north[64],int16_t quantization[64]);
static int DecodeACComponent(WinZipJPEGDecompressor *self,int comp,unsigned int k,
int16_t current[64],int16_t west[64],int16_t north[64],int16_t quantization[64]);
static int DecodeACSign(WinZipJPEGDecompressor *self,int comp,unsigned int k,int absvalue,
int16_t current[64],int16_t west[64],int16_t north[64],int16_t quantization[64]);

static bool IsFirstRow(unsigned int k);
static bool IsFirstColumn(unsigned int k);
static bool IsFirstRowOrColumn(unsigned int k);
static bool IsSecondRow(unsigned int k);
static bool IsSecondColumn(unsigned int k);

static unsigned int Left(unsigned int k);
static unsigned int Up(unsigned int k);
static unsigned int UpAndLeft(unsigned int k);
static unsigned int Right(unsigned int k);
static unsigned int Down(unsigned int k);

static unsigned int ZigZag(unsigned int row,unsigned int column);
static unsigned int Row(unsigned int k);
static unsigned int Column(unsigned int k);

static int Min(int a,int b);
static int Abs(int x);
static int Sign(int x);
static unsigned int Category(uint16_t val);

static int Sum(unsigned int k,int16_t block[64]);
static int Average(unsigned int k,int16_t north[64],int16_t west[64],int16_t quantization[64]);
static int BDR(unsigned int k,int16_t current[64],int16_t north[64],int16_t west[64],int16_t quantization[64]);




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

	// Initialize arithmetic decoder contexts.
	InitializeWinZipJPEGContexts(&self->eobbins[0][0][0],sizeof(self->eobbins));
	InitializeWinZipJPEGContexts(&self->zerobins[0][0][0][0],sizeof(self->zerobins));
	InitializeWinZipJPEGContexts(&self->pivotbins[0][0][0][0],sizeof(self->pivotbins));
	InitializeWinZipJPEGContexts(&self->magnitudebins[0][0][0][0][0],sizeof(self->magnitudebins));
	InitializeWinZipJPEGContexts(&self->remainderbins[0][0][0][0],sizeof(self->remainderbins));
	InitializeWinZipJPEGContexts(&self->signbins[0][0][0][0],sizeof(self->signbins));

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
		if(!ParseWinZipJPEGMetadata(&self->jpeg,
		self->metadatabytes,self->metadatalength)) return WinZipJPEGParseError;
		self->hasparsedjpeg=true;
	}

	// Initialize arithmetic coder for reading scans.
	InitializeWinZipJPEGArithmeticDecoder(&self->decoder,self->readfunc,self->inputcontext);

	// Initialize arithmetic coder contexts.
	// ...

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

	for(int comp=0;comp<self->jpeg.numscancomponents;comp++)
	{
	}
}


static void DecodeMCU(WinZipJPEGDecompressor *self,int comp,int x,int y,
int16_t current[64],int16_t west[64],int16_t north[64],int16_t quantization[64])
{
	// Decode End Of Block value to find out how many AC components there are. (5.6.5)

	// Calculate EOB context. (5.6.5.2)
	int average;
	if(x==0&&y==0) average=0;
	if(x==0) average=Sum(0,north);
	else if(y==0) average=Sum(0,west);
	else average=(Sum(0,north)+Sum(0,west)+1)/2;

	int eobcontext=Min(Category(average),12);

	// Decode EOB bits using binary tree. (5.6.5.1)
	unsigned int bitstring=1;
	for(int i=0;i<6;i++)
	{
		bitstring|=(bitstring<<1)|NextBitFromWinZipJPEGArithmeticDecoder(&self->decoder,
		&self->eobbins[comp][eobcontext][bitstring]);
	}
	unsigned int eob=bitstring&0x3f;

	// Fill out the elided block entries with 0.
	for(unsigned int k=eob+1;k<=63;k++) current[k]=0;

	// Decode AC components in decreasing order, if any. (5.6.6)
	for(unsigned int k=eob;k>=1;k--)
	{
		DecodeACComponent(self,comp,k,current,west,north,quantization);
	}

	// Decode DC component. (5.6.7)
}

static int DecodeACComponent(WinZipJPEGDecompressor *self,int comp,unsigned int k,
int16_t current[64],int16_t west[64],int16_t north[64],int16_t quantization[64])
{
	// Decode zero/non-zero bit. (5.6.6.1)
	int val1;
	if(IsFirstRowOrColumn(k)) val1=Abs(BDR(k,current,north,west,quantization));
	else val1=Average(k,north,west,quantization);

	int val2=Sum(k,current);

	int zerocontext1=Min(Category(val1),2);
	int zerocontext2=Min(Category(val2),5);
	int nonzero=NextBitFromWinZipJPEGArithmeticDecoder(&self->decoder,
	&self->zerobins[comp][k-1][zerocontext1][zerocontext2]);

	// If this component is zero, there is no need to decode further parameters.
	if(!nonzero) return 0;

	// This component is not zero. Proceed with decoding absolute value.
	int absvalue;

	// Decode pivot (abs>=2). (5.6.6.2)
	int pivotcontext1=Min(Category(val1),4);
	int pivotcontext2=Min(Category(val2),6);
	int pivot=NextBitFromWinZipJPEGArithmeticDecoder(&self->decoder,
	&self->pivotbins[comp][k-1][pivotcontext1][pivotcontext2]);

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

		int magnitudecontext1=Min(Category(val1),8);
		int magnitudecontext2=Min(Category(val2),8);
		int remaindercontext1=val3;

		// Decode binarization. (5.6.4)

		// Decode unary header.
		int ones=0;
		while(ones<9)
		{
			int unary=NextBitFromWinZipJPEGArithmeticDecoder(&self->decoder,
			&self->magnitudebins[comp][n][magnitudecontext1][magnitudecontext2][ones]);
			if(unary==1) ones++;
			else break;
		}

		// Decode remainder bits, if any.
		if(ones==0) absvalue=2;
		else if(ones==1) absvalue=3;
		else
		{
			int numbits=ones-1;
			int val=1<<numbits;

			for(int i=0;i<numbits;i++)
			{
				int bit=NextBitFromWinZipJPEGArithmeticDecoder(&self->decoder,
				&self->remainderbins[comp][n][remaindercontext1][i]);

				val|=bit<<i; // TODO: Is this correct? No idea! Spec sure doesn't say!
			}

			absvalue=val+2;
		}
	}

	if(DecodeACSign(self,comp,k,absvalue,current,west,north,quantization)) return -absvalue;
	else return absvalue;
}


static int DecodeACSign(WinZipJPEGDecompressor *self,int comp,unsigned int k,int absvalue,
int16_t current[64],int16_t west[64],int16_t north[64],int16_t quantization[64])
{
	// Decode sign. (5.6.6.4)

	// Calculate sign context, or decode with fixed probability. (5.6.6.4.1)
	int predictedsign;
	if(IsFirstRowOrColumn(k))
	{
		int bdr=BDR(k,current,north,west,quantization);

		if(bdr==0) return NextBitFromWinZipJPEGArithmeticDecoder(&self->decoder,&self->fixedcontext);

		predictedsign=(bdr<0);
	}
	else if(k==4)
	{
		int sign1=Sign(north[k]);
		int sign2=Sign(west[k]);

		if(sign1+sign2==0) NextBitFromWinZipJPEGArithmeticDecoder(&self->decoder,&self->fixedcontext);

		predictedsign=(sign1+sign2<0);
	}
	else if(IsSecondRow(k))
	{
		if(north[k]==0) return NextBitFromWinZipJPEGArithmeticDecoder(&self->decoder,&self->fixedcontext);

		predictedsign=(north[k]<0);
	}
	else if(IsSecondColumn(k))
	{
		if(west[k]==0) return NextBitFromWinZipJPEGArithmeticDecoder(&self->decoder,&self->fixedcontext);

		predictedsign=(west[k]<0);
	}
	else
	{
		return NextBitFromWinZipJPEGArithmeticDecoder(&self->decoder,&self->fixedcontext);
	}

	static const int n_for_k[64]={
		 0,
		 0, 1,
		 2, 3, 4,
		 5, 6, 7, 8,
		 9,10, 0,11,12,
		13,14, 0, 0,15,16,
		17,18, 0, 0, 0,19,20,
		21,22, 0, 0, 0, 0,23,24,
		25, 0, 0, 0, 0, 0,26,
		 0, 0, 0, 0, 0, 0,
		 0, 0, 0, 0, 0,
		 0, 0, 0, 0,
		 0, 0, 0,
		 0, 0,
		 0,
	};
	int n=n_for_k[k];

	int signcontext1=Min(Category(absvalue)/2,2);

	return NextBitFromWinZipJPEGArithmeticDecoder(&self->decoder,
	&self->signbins[comp][n][signcontext1][predictedsign]);
}

static bool IsFirstRow(unsigned int k) { return Row(k)==0; }
static bool IsFirstColumn(unsigned int k) { return Column(k)==0; }
static bool IsFirstRowOrColumn(unsigned int k) { return IsFirstRow(k)||IsFirstColumn(k); }
static bool IsSecondRow(unsigned int k) { return Row(k)==1; }
static bool IsSecondColumn(unsigned int k) { return Column(k)==1; }

static unsigned int Left(unsigned int k) { return ZigZag(Row(k),Column(k)-1); }
static unsigned int Up(unsigned int k) { return ZigZag(Row(k)-1,Column(k)); }
static unsigned int UpAndLeft(unsigned int k) { return ZigZag(Row(k)-1,Column(k)-1); }
static unsigned int Right(unsigned int k) { return ZigZag(Row(k),Column(k)+1); }
static unsigned int Down(unsigned int k) { return ZigZag(Row(k)+1,Column(k)); }

static unsigned int ZigZag(unsigned int row,unsigned int column)
{
	if(row>=8||column>=8) return 0; // Can't happen.
	return (int[8][8]){
		{  0, 1, 5, 6,14,15,27,28, },
		{  2, 4, 7,13,16,26,29,42, },
		{  3, 8,12,17,25,30,41,43, },
		{  9,11,18,24,31,40,44,53, },
		{ 10,19,23,32,39,45,52,54, },
		{ 20,22,33,38,46,51,55,60, },
		{ 21,34,37,47,50,56,59,61, },
		{ 35,36,48,49,57,58,62,63, },
	}[row][column];
}

static unsigned int Row(unsigned int k)
{
	if(k>=64) return 0; // Can't happen.
	return (int[64]){
		0,0,1,2,1,0,0,1,2,3,4,3,2,1,0,0,
		1,2,3,4,5,6,5,4,3,2,1,0,0,1,2,3,
		4,5,6,7,7,6,5,4,3,2,1,2,3,4,5,6,
		7,7,6,5,4,3,4,5,6,7,7,6,5,6,7,7,
	}[k];
}

static unsigned int Column(unsigned int k)
{
	if(k>=64) return 0; // Can't happen.
	return (int[64]){
		0,1,0,0,1,2,3,2,1,0,0,1,2,3,4,5,
		4,3,2,1,0,0,1,2,3,4,5,6,7,6,5,4,
		3,2,1,0,1,2,3,4,5,6,7,7,6,5,4,3,
		2,3,4,5,6,7,7,6,5,4,5,6,7,7,6,7,
	}[k];
}

static int Min(int a,int b)
{
	if(a<b) return a;
	else return b;
}

static int Abs(int x)
{
	if(x>=0) return x;
	else return -x;
}

static int Sign(int x)
{
	if(x>0) return 1;
	else if(x<0) return -1;
	else return 0;
}

static unsigned int Category(uint16_t val)
{
	unsigned int cat=0;
	if(val&0xff00) { val>>=8; cat|=8; }
	if(val&0xf0) { val>>=4; cat|=4; }
	if(val&0xc) { val>>=2; cat|=2; }
	if(val&0x2) { val>>=1; cat|=1; }
	return cat;
}

// 5.6.2.1 SUM
static int Sum(unsigned int k,int16_t block[64])
{
	int sum=0;
	for(unsigned int i=0;i<64;i++)
	{
		if(i!=k && Row(i)>=Row(k) && Column(i)>=Column(k)) sum+=Abs(block[i]);
	}
}

// 5.6.2.2 AVG
// NOTE: This assumes that the expression given for 'sum' is incorrect, and that
// Bw[k] should actually be Bw[x].
static int Average(unsigned int k,int16_t north[64],int16_t west[64],int16_t quantization[64])
{
	if(k==0) return 0; // Can't happen.
	else if(IsFirstRow(k))
	{
		int sum=(Abs(north[Left(k)])+Abs(west[Left(k)]))*quantization[Left(k)]/quantization[k];
		return (sum+Abs(north[k])+Abs(west[k])+1)/(2*1);
	}
	else if(IsFirstColumn(k))
	{
		int sum=(Abs(north[Up(k)])+Abs(west[Up(k)]))*quantization[Left(k)]/quantization[k];
		return (sum+Abs(north[k])+Abs(west[k])+1)/(2*1);
	}
	else
	{
		int sum=0;
		sum+=(Abs(north[Left(k)])+Abs(west[Left(k)]))*quantization[Left(k)]/quantization[k];
		sum+=(Abs(north[Up(k)])+Abs(west[Up(k)]))*quantization[Up(k)]/quantization[k];
		sum+=(Abs(north[UpAndLeft(k)])+Abs(west[UpAndLeft(k)]))*quantization[UpAndLeft(k)]/quantization[k];
		return (sum+Abs(north[k])+Abs(west[k])+3)/(2*3);
	}
}

// 5.6.2.3 BDR
static int BDR(unsigned int k,int16_t current[64],int16_t north[64],int16_t west[64],int16_t quantization[64])
{
	if(IsFirstRow(k))
	{
		return north[k]-(north[Down(k)]+current[Down(k)])*quantization[Down(k)]/quantization[k];
	}
	else if(IsFirstColumn(k))
	{
		return west[k]-(west[Right(k)]+current[Right(k)])*quantization[Right(k)]/quantization[k];
	}
	else return 0; // Can't happen.
}
