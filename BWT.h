#ifndef __BWT_H__
#define __BWT_H__

#include <stdint.h>

void CalculateInverseBWT(int *transform,uint8_t *block,int blocklen);
void UnsortBWT(uint8_t *block,int blocklen,int firstindex);

void UnsortBWTStuffItX(uint8_t *block,int blocklen,int firstindex);

typedef struct MTFState
{
	int table[256];
} MTFState;

void ResetMTFDecoder(MTFState *mtf);
int DecodeMTF(MTFState *mtf,int symbol);
void DecodeMTFBlock(uint8_t *block,int blocklen);
void DecodeM1FFNBlock(uint8_t *block,int blocklen,int order);

#endif
