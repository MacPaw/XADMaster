#ifndef __WINZIP_JPEG_ARITHMETIC_DECODER_H__
#define __WINZIP_JPEG_ARITHMETIC_DECODER_H__

#include "InputStream.h"

typedef struct WinZipJPEGArithmeticDecoder
{
	WinZipJPEGReadFunction *readfunc;
	void *inputcontext;

	uint32_t i,bl,p;

	uint8_t b,b0;

	uint8_t mps; // most probable symbol value - 0 or 1
	uint8_t yn; // symbol to be coded
	uint8_t k; // least probable symbol count
	uint8_t kmin2; // LPS count for reduction of Q by 4
	uint8_t kmin1; // LPS count for reduction of Q by 2
	uint8_t kmin; // largest LSP[sic] count for smaller Q
	//uint8_t kavg; // expected average LPS count
	uint8_t kmax; // smallest LPS count for larger Q
	uint32_t x; // finite pricesion window on code stream
	uint16_t lp; // minus log p
	uint16_t lr; // minus log of the range
	uint16_t dlrm; // difference between lrm and lr
	uint16_t lrm; // maximum lr before change index
	uint16_t lrt; // decoder - minimum of lrm and lx
	uint16_t lx; // decoder - log x
	uint32_t mr; // mantissa of range for calculating antilog
	uint32_t dx; // antilog of lr
	uint32_t ct; // decoder - number of bits to shift for logx
	uint32_t cx; // decoder - characteristic of x
	uint32_t xf; // fractional part of x

	uint16_t incrsv; // save extra increments at MPS exchange

	// statistics based on s (old state initially)
	uint32_t s; // pointer to statistics for this state (???)
	uint32_t ist[1]; // index into probtbl (base s) (???)
	uint16_t dlrst[1]; // lrm-lr+lp (base s)
	uint8_t mpsst[1]; // most probably symbol (base s)
	uint8_t kst[1]; // lps count (base s)

	uint32_t ns; //  (???)

} WinZipJPEGArithmeticDecoder;

void InitializeWinZipJPEGArithmeticDecoder(WinZipJPEGArithmeticDecoder *self,WinZipJPEGReadFunction *readfunc, void *inputcontext);

#endif

