#import "StuffItXUtilities.h"

uint64_t ReadSitxP2(CSHandle *fh)
{
	int n=1;
	while([fh readBitsLE:1]==1) n++;

	uint64_t value=0;
	uint64_t bit=1;

	while(n)
	{
		if([fh readBitsLE:1]==1)
		{
			n--;
			value|=bit;
		}
		bit<<=1;
	}
	return value-1;
}

uint64_t CSInputNextSitxP2(CSInputBuffer *input)
{
	int n=1;
	while(CSInputNextBitLE(input)==1) n++;

	uint64_t value=0;
	uint64_t bit=1;

	while(n)
	{
		if(CSInputNextBitLE(input)==1)
		{
			n--;
			value|=bit;
		}
		bit<<=1;
	}
	return value-1;
}
