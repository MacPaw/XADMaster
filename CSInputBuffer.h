#import <Foundation/Foundation.h>
#import "CSHandle.h"

typedef struct CSInputBuffer
{
	CSHandle *parent;
	off_t startoffs;
	BOOL eof;

	uint8_t *buffer;
	int bufsize,bufbytes,currbyte,currbit;
} CSInputBuffer;

CSInputBuffer *CSInputBufferAlloc(CSHandle *parent,int size);
void CSInputBufferFree(CSInputBuffer *buf);

void CSInputRestart(CSInputBuffer *buf);
void CSInputFlush(CSInputBuffer *buf);
void CSInputSeekToOffset(CSInputBuffer *buf,off_t offset);
void CSInputSetStartOffset(CSInputBuffer *buf,off_t offset);

off_t CSInputBufferOffset(CSInputBuffer *buf);

void _CSInputFillBuffer(CSInputBuffer *buf);

void CSInputSkipBits(CSInputBuffer *buf,int bits);
BOOL CSInputOnByteBoundary(CSInputBuffer *buf);
void CSInputSkipToByteBoundary(CSInputBuffer *buf);

int CSInputNextBit(CSInputBuffer *buf);
int CSInputNextBitLE(CSInputBuffer *buf);
unsigned int CSInputNextBitString(CSInputBuffer *buf,int bits);
unsigned int CSInputNextBitStringLE(CSInputBuffer *buf,int bits);
unsigned int CSInputPeekBitString(CSInputBuffer *buf,int bits);
unsigned int CSInputPeekBitStringLE(CSInputBuffer *buf,int bits);

#define CSInputBufferLookAhead 4

static inline void _CSInputCheckAndFillBuffer(CSInputBuffer *buf)
{
	if(!buf->eof&&buf->currbyte+CSInputBufferLookAhead>=buf->bufbytes) _CSInputFillBuffer(buf);
}

static inline void CSInputSkipBytes(CSInputBuffer *buf,int num) { buf->currbyte+=num; }

static inline int CSInputPeekByte(CSInputBuffer *buf,int offs)
{
	if(buf->currbyte+offs>=buf->bufbytes) [buf->parent _raiseEOF];

	return buf->buffer[buf->currbyte+offs];
}

static inline int CSInputNextByte(CSInputBuffer *buf)
{
	_CSInputCheckAndFillBuffer(buf);
	int byte=CSInputPeekByte(buf,0);
	CSInputSkipBytes(buf,1);
	return byte;
}

// TODO: Move to endianaccess, implement and use CSInputBytePointer()
static inline uint16_t CSInputNextUInt16LE(CSInputBuffer *buf)
{
	uint16_t val=CSInputNextByte(buf);
	val|=(uint16_t)CSInputNextByte(buf)<<8;
	return val;
}




