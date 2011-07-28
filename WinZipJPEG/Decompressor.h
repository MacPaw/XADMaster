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


	WinZipJPEGArithmeticDecoder decoder;

	WinZipJPEGContext eobbins[4][12][64];
	WinZipJPEGContext zerobins[4][62][3][6];
	WinZipJPEGContext pivotbins[4][63][5][7]; // Why 63?
	WinZipJPEGContext magnitudebins[4][3][9][9][9];
	WinZipJPEGContext remainderbins[4][13][3][7];
	WinZipJPEGContext signbins[4][27][3][2];
} WinZipJPEGDecompressor;

WinZipJPEGDecompressor *AllocWinZipJPEGDecompressor(WinZipJPEGReadFunction *readfunc,void *inputcontext);
void FreeWinZipJPEGDecompressor(WinZipJPEGDecompressor *self);

int ReadWinZipJPEGHeader(WinZipJPEGDecompressor *self);

int ReadNextWinZipJPEGBundle(WinZipJPEGDecompressor *self);

static inline bool IsFinalWinZipJPEGBundle(WinZipJPEGDecompressor *self) { return self->isfinalbundle; }

static inline uint32_t WinZipJPEGBundleMetadataLength(WinZipJPEGDecompressor *self) { return self->metadatalength; }
static inline uint8_t *WinZipJPEGBundleMetadataBytes(WinZipJPEGDecompressor *self) { return self->metadatabytes; }

#endif

