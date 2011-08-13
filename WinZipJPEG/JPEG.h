#ifndef __WINZIP_JPEG_JPEG_H__
#define __WINZIP_JPEG_JPEG_H__

#include <stdint.h>
#include <stdbool.h>
#include <stdlib.h>

typedef struct WinZipJPEGMetadata
{
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

	int16_t quantizationtables[4][64];

	struct
	{
		unsigned int code,length;
	} huffmantables[2][4][256];
} WinZipJPEGMetadata;

bool ParseWinZipJPEGMetadata(WinZipJPEGMetadata *self,uint8_t *bytes,size_t length);

#endif
