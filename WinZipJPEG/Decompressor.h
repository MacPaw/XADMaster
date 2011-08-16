#ifndef __WINZIP_JPEG_DECOMPRESSOR_H__
#define __WINZIP_JPEG_DECOMPRESSOR_H__

#include "InputStream.h"
#include "ArithmeticDecoder.h"
#include "JPEG.h"

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
	WinZipJPEGMetadata jpeg;

	WinZipJPEGArithmeticDecoder decoder;

	WinZipJPEGContext eobbins[4][13][63]; // 321 in WinZip.
	WinZipJPEGContext zerobins[4][62][3][6]; // 1140 in WinZip.
	WinZipJPEGContext pivotbins[4][63][5][7];
	WinZipJPEGContext acmagnitudebins[4][3][9][9][9];
	WinZipJPEGContext acremainderbins[4][13][3][7];
	WinZipJPEGContext acsignbins[4][27][3][2];
	WinZipJPEGContext dcmagnitudebins[4][13][10]; // 1 in WinZip.
	WinZipJPEGContext dcremainderbins[4][13][14]; // 131 in WinZip.
	WinZipJPEGContext dcsignbins[4][2][2][2]; // 313 in WinZip.
	WinZipJPEGContext fixedcontext;
} WinZipJPEGDecompressor;

WinZipJPEGDecompressor *AllocWinZipJPEGDecompressor(WinZipJPEGReadFunction *readfunc,void *inputcontext);
void FreeWinZipJPEGDecompressor(WinZipJPEGDecompressor *self);

int ReadWinZipJPEGHeader(WinZipJPEGDecompressor *self);

int ReadNextWinZipJPEGBundle(WinZipJPEGDecompressor *self);

void TestDecompress(WinZipJPEGDecompressor *self);

static inline bool IsFinalWinZipJPEGBundle(WinZipJPEGDecompressor *self) { return self->isfinalbundle; }

static inline uint32_t WinZipJPEGBundleMetadataLength(WinZipJPEGDecompressor *self) { return self->metadatalength; }
static inline uint8_t *WinZipJPEGBundleMetadataBytes(WinZipJPEGDecompressor *self) { return self->metadatabytes; }

#endif

