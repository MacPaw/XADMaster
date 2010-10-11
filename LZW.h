#ifndef __LZW_H__
#define __LZW_H__

#include <stdint.h>
#include <stdbool.h>

#define LZWNoError 0
#define LZWInvalidCodeError 1
#define LZWTooManyCodesError 2

typedef struct LZWTreeNode
{
	uint8_t chr;
	int parent;
} LZWTreeNode;

typedef struct LZW
{
	LZWTreeNode *nodes;
	int numsymbols,maxsymbols,reservedsymbols;
	int prevsymbol;

	uint8_t *buffer;
	int buffersize;
} LZW;

LZW *AllocLZW(int maxsymbols,int reservedsymbols);
void FreeLZW(LZW *self);
void ClearLZWTable(LZW *self);
int NextLZWSymbol(LZW *self,int symbol);
int LZWOutputLength(LZW *self);
int LZWOutputToBuffer(LZW *self,uint8_t *buffer);
int LZWReverseOutputToBuffer(LZW *self,uint8_t *buffer);
int LZWOutputToInternalBuffer(LZW *self);

static inline uint8_t *LZWInternalBuffer(LZW *self)
{
	return self->buffer;
}

static inline int LZWSymbolCount(LZW *self)
{
	return self->numsymbols;
}

static inline bool LZWSymbolListFull(LZW *self)
{
	return self->numsymbols==self->maxsymbols;
}

#endif

