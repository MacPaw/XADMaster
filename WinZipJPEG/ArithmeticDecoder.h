#ifndef __WINZIP_JPEG_ARITHMETIC_DECODER_H__
#define __WINZIP_JPEG_ARITHMETIC_DECODER_H__

#include "InputStream.h"

typedef struct WinZipJPEGArithmeticDecoder
{
	WinZipJPEGReadFunction *readfunc;
	void *inputcontext;

	uint8_t b,b0;

	uint8_t kmin2; // LPS count for reduction of Q by 4
	uint8_t kmin1; // LPS count for reduction of Q by 2
	uint8_t kmin; // largest LSP[sic] count for smaller Q
	//uint8_t kavg; // expected average LPS count
	uint8_t kmax; // smallest LPS count for larger Q
	uint32_t x; // finite pricesion window on code stream
	uint16_t lp; // minus log p --- used only for testing
	uint16_t lr; // minus log of the range
	uint16_t lrm; // maximum lr before change index
	uint16_t lx; // decoder - log x
	uint32_t dx; // antilog of lr -- used only for testing
} WinZipJPEGArithmeticDecoder;

typedef struct WinZipJPEGContext
{
	int i;
	int32_t dlrm; // difference between lrm and lr
	uint8_t mps; // most probable symbol value - 0 or 1
	uint8_t k; // least probable symbol count
} WinZipJPEGContext;

void InitializeWinZipJPEGArithmeticDecoder(WinZipJPEGArithmeticDecoder *self,WinZipJPEGReadFunction *readfunc, void *inputcontext);
void InitializeWinZipJPEGContext(WinZipJPEGContext *self);

int NextBitFromWinZipJPEGArithmeticDecoder(WinZipJPEGArithmeticDecoder *self,WinZipJPEGContext *context);

#endif

