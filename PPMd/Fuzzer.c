#include <stdio.h>

#include "VariantG.h"
#include "VariantH.h"
#include "VariantI.h"
#include "SubAllocatorVariantG.h"
#include "SubAllocatorVariantH.h"
#include "SubAllocatorVariantI.h"
#include "SubAllocatorBrimstone.h"

static int FuzzerFunction1(void *context);
static int FuzzerFunction2(void *context);
static int FuzzerFunction3(void *context);

static void SeedRandom(uint32_t seed);
static uint32_t Random();

int main(int argc,const char **argv)
{
	if(argc!=3&&argc!=4&&argc!=5)
	{
		fprintf(stderr,"Usage: %s variant mode [seed [length]]\n",argv[0]);
		fprintf(stderr,"       \"variant\" is g, h, i, b or 7.\n");
		fprintf(stderr,"       \"mode\" is 1-3.\n");
		fprintf(stderr,"       \"seed\" is the random seed to use (defaults to 0).\n");
		fprintf(stderr,"       \"length\" is the number of bytes to read (defaults to infinite).\n");
		return 1;
	}

	PPMdReadFunction *readfunc;
	switch(argv[2][0])
	{
		case '1': readfunc=FuzzerFunction1; break;
		case '2': readfunc=FuzzerFunction2; break;
		case '3': readfunc=FuzzerFunction3; break;
		default:
			fprintf(stderr,"Unknown mode.\n");
			return 1;
	}

	uint32_t seed=0;
	if(argc>3) seed=atoi(argv[3]);
	SeedRandom(seed);

	int length=0;
	if(argc>4) seed=atoi(argv[4]);

	switch(argv[1][0])
	{
		case 'g':
		case 'G':
		{
			PPMdSubAllocatorVariantG *alloc=CreateSubAllocatorVariantG(1024*1024);
			PPMdModelVariantG model;
			StartPPMdModelVariantG(&model,readfunc,NULL,&alloc->core,16,false);

			if(length) for(int i=0;i<length;i++) NextPPMdVariantGByte(&model);
			else for(;;) NextPPMdVariantGByte(&model);
		}
		break;

		case 'b':
		case 'B':
		{
			PPMdSubAllocatorBrimstone *alloc=CreateSubAllocatorBrimstone(1024*1024);
			PPMdModelVariantG model;
			StartPPMdModelVariantG(&model,readfunc,NULL,&alloc->core,16,true);

			if(length) for(int i=0;i<length;i++) NextPPMdVariantGByte(&model);
			else for(;;) NextPPMdVariantGByte(&model);
		}
		break;

		case 'h':
		case 'H':
		{
			PPMdSubAllocatorVariantH *alloc=CreateSubAllocatorVariantH(1024*1024);
			PPMdModelVariantH model;
			StartPPMdModelVariantH(&model,readfunc,NULL,alloc,16,false);

			if(length) for(int i=0;i<length;i++) NextPPMdVariantHByte(&model);
			else for(;;) NextPPMdVariantHByte(&model);
		}
		break;

		case '7':
		{
			PPMdSubAllocatorVariantH *alloc=CreateSubAllocatorVariantH(1024*1024);
			PPMdModelVariantH model;
			StartPPMdModelVariantH(&model,readfunc,NULL,alloc,16,true);

			if(length) for(int i=0;i<length;i++) NextPPMdVariantHByte(&model);
			else for(;;) NextPPMdVariantHByte(&model);
		}
		break;

		case 'i':
		case 'I':
		{
			PPMdSubAllocatorVariantI *alloc=CreateSubAllocatorVariantI(1024*1024);
			PPMdModelVariantI model;
			StartPPMdModelVariantI(&model,readfunc,NULL,alloc,16,0);

			if(length) for(int i=0;i<length;i++) NextPPMdVariantIByte(&model);
			else for(;;) NextPPMdVariantIByte(&model);
		}
		break;

		default:
			fprintf(stderr,"Unknown variant.\n");
			return 1;
	}

	return 0;
}

static int FuzzerFunction1(void *context)
{
	return Random()&0xff;
}

static int FuzzerFunction2(void *context)
{
	return Random()&Random()&Random()&0xff;
}

static int FuzzerFunction3(void *context)
{
	return (Random()|Random()|Random())&0xff;
}




static uint32_t s1=0xc7ff5f16,s2=0x0dc556ae,s3=0x78010089;

static void SeedRandom(uint32_t seed)
{
	s1=seed*1664525+1013904223|0x10;
	s2=seed*1103515245+12345|0x1000;
	s3=seed*214013+2531011|0x100000;
}

static uint32_t Random()
{
	s1=((s1&0xfffffffe)<<12)^(((s1<<13)^s1)>>19);
	s2=((s2&0xfffffff8)<<4)^(((s2<<2)^s2)>>25);
	s3=((s3&0xfffffff0)<<17)^(((s3<<3)^s3)>>11);
	return s1^s2^s3;
}
