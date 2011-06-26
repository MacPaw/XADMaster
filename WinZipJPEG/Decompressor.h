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

	int slicevalue;

	uint32_t metadatalength;
	uint8_t *metadatabytes;
	bool isfinalbundle;

	bool hasparsedjpeg;

	int width,height,bits;
	int restartinterval;

	int numcomponents;
	struct
	{
		int identifier;
		int horizontalfactor,verticalfactor;
		int quantizationtable;
	} components[4];

	int numscancomponents;
	struct
	{
		int componentindex;
		int dctable,actable;
	} scancomponents[4];

	int numquantizations;
	uint8_t quantizations[4][64];

} WinZipJPEGDecompressor;

WinZipJPEGDecompressor *AllocWinZipJPEGDecompressor(WinZipJPEGReadFunction *readfunc,void *inputcontext);
void FreeWinZipJPEGDecompressor(WinZipJPEGDecompressor *self);

int ReadWinZipJPEGHeader(WinZipJPEGDecompressor *self);

int ReadNextWinZipJPEGBundle(WinZipJPEGDecompressor *self);

static inline bool IsFinalWinZipJPEGBundle(WinZipJPEGDecompressor *self) { return self->isfinalbundle; }

static inline uint32_t WinZipJPEGBundleMetadataLength(WinZipJPEGDecompressor *self) { return self->metadatalength; }
static inline uint8_t *WinZipJPEGBundleMetadataBytes(WinZipJPEGDecompressor *self) { return self->metadatabytes; }

#endif

