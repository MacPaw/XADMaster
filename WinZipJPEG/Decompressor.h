#ifndef __WINZIP_JPEG_DECOMPRESSOR_H__
#define __WINZIP_JPEG_DECOMPRESSOR_H__

#include "InputStream.h"
#include "ArithmeticDecoder.h"

#include <stdint.h>
#include <stdbool.h>

#define WinZipJPEGNoError 0
#define WinZipJPEGEndOfStreamError 1
#define WinZipJPEGOutOfMemoryError 2
#define WinZipJPEGInvalidHeaderError 3
#define WinZipJPEGLZMAError 4
#define WinZipJPEGParseError 5

typedef struct WinZipJPEGDecompressor
{
	WinZipJPEGReadFunction *readfunc;
	void *inputcontext;

	WinZipJPEGArithmeticDecoder decoder;

	unsigned int slicevalue;

	uint32_t metadatalength;
	uint8_t *metadatabytes;
	bool isfinalbundle;

	bool hasparsedjpeg;

	unsigned int width,height,bits;
	unsigned int restartinterval;

	unsigned int numcomponents;
	struct
	{
		unsigned int identifier;
		unsigned int horizontalfactor,verticalfactor;
		unsigned int quantizationtable;
	} components[4];

	unsigned int numscancomponents;
	struct
	{
		unsigned int componentindex;
		unsigned int dctable,actable;
	} scancomponents[4];

	unsigned int quantizationtables[4][64];

	struct
	{
		unsigned int code,length;
	} huffmantables[2][4][256];
} WinZipJPEGDecompressor;

WinZipJPEGDecompressor *AllocWinZipJPEGDecompressor(WinZipJPEGReadFunction *readfunc,void *inputcontext);
void FreeWinZipJPEGDecompressor(WinZipJPEGDecompressor *self);

int ReadWinZipJPEGHeader(WinZipJPEGDecompressor *self);

int ReadNextWinZipJPEGBundle(WinZipJPEGDecompressor *self);

static inline bool IsFinalWinZipJPEGBundle(WinZipJPEGDecompressor *self) { return self->isfinalbundle; }

static inline uint32_t WinZipJPEGBundleMetadataLength(WinZipJPEGDecompressor *self) { return self->metadatalength; }
static inline uint8_t *WinZipJPEGBundleMetadataBytes(WinZipJPEGDecompressor *self) { return self->metadatabytes; }

#endif

