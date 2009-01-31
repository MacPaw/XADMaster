#include "BWT.h"

#include <stdlib.h>
#include <string.h>

// Inverse BWT

void CalculateInverseBWT(int *transform,uint8_t *block,int blocklen)
{
	int counts[256]={0},cumulativecounts[256];
	
	for(int i=0;i<blocklen;i++) counts[block[i]]++;
	
	int total=0;
	for(int i=0;i<256;i++)
	{
		cumulativecounts[i]=total;
		total+=counts[i];
		counts[i]=0;
	}
	
	for(int i=0;i<blocklen;i++)
	{
		transform[cumulativecounts[block[i]]+counts[block[i]]]=i;
		counts[block[i]]++;
	}
}

/*void UnsortBWT(uint8_t *block,int blocklen,int firstindex)
{
	int *transform=malloc(blocklen*sizeof(int));
	uint8_t *tmp=malloc(blocklen);

	CalculateInverseBWT(transform,block,blocklen);

	int transformindex=firstindex;
	for(int i=0;i<blocklen;i++)
	{
		transformindex=transform[transformindex];
		tmp[i]=block[transformindex];
	}

	memcpy(block,tmp,blocklen);

	free(transform);
	free(tmp);
}*/

void UnsortBWTStuffItX(uint8_t *dest,int blocklen,int firstindex,uint8_t *src,uint32_t *transform)
{
	int counts[256]={0};

	for(int i=0;i<blocklen;i++)
	{
		transform[i]=counts[src[i]];
		counts[src[i]]++;
	}

	int total=0;
	for(int i=0;i<256;i++)
	{
		int oldtotal=total;
		total+=counts[i];
		counts[i]=oldtotal;
	}

	int index=firstindex;
	for(int i=blocklen-1;i>=0;i--)
	{
		dest[i]=src[index];
		index=transform[index]+counts[src[index]];
	}
}




// MTF Decoder

void ResetMTFDecoder(MTFState *mtf)
{
	for(int i=0;i<256;i++) mtf->table[i]=i;
}

int DecodeMTF(MTFState *mtf,int symbol)
{
	int res=mtf->table[symbol];
	for(int i=symbol;i>0;i--) mtf->table[i]=mtf->table[i-1];
	mtf->table[0]=res;
	return res;
}

void DecodeMTFBlock(uint8_t *block,int blocklen)
{
	MTFState mtf;
	ResetMTFDecoder(&mtf);
	for(int i=0;i<blocklen;i++) block[i]=DecodeMTF(&mtf,block[i]);
}

void DecodeM1FFNBlock(uint8_t *block,int blocklen,int order)
{
	MTFState mtf;
	ResetMTFDecoder(&mtf);
	int lasthead=order-1;

	for(int i=0;i<blocklen;i++)
	{
		int symbol=block[i];
		block[i]=mtf.table[symbol];

		if(symbol==0)
		{
			lasthead=0;
		}
		else if(symbol==1)
		{
			if(lasthead>=order)
			{
				int val=mtf.table[1];
				mtf.table[1]=mtf.table[0];
				mtf.table[0]=val;
			}
		}
		else
		{
			int val=mtf.table[symbol];
			for(int i=symbol;i>1;i--) mtf.table[i]=mtf.table[i-1];
			mtf.table[1]=val;
		}

		lasthead++;
	}
}
