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

	int maxhorizontalfactor,maxverticalfactor;

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

static inline int JPEGMCUWidthInBlocks(WinZipJPEGMetadata *self) { return self->maxhorizontalfactor; }
static inline int JPEGMCUHeightInBlocks(WinZipJPEGMetadata *self) { return self->maxverticalfactor; }
static inline int JPEGMCUWidthInPixels(WinZipJPEGMetadata *self) { return JPEGMCUWidthInBlocks(self)*8; }
static inline int JPEGMCUHeightInPixels(WinZipJPEGMetadata *self) { return JPEGMCUHeightInBlocks(self)*8; }

static inline int JPEGWidthInPixels(WinZipJPEGMetadata *self) { return self->width; }
static inline int JPEGHeightInPixels(WinZipJPEGMetadata *self) { return self->height; }
static inline int JPEGWidthInMCUs(WinZipJPEGMetadata *self)
{
	int mcuwidth=JPEGMCUWidthInPixels(self);
	return (JPEGWidthInPixels(self)+mcuwidth-1)/mcuwidth;
}
static inline int JPEGHeightInMCUs(WinZipJPEGMetadata *self)
{
	int mcuheight=JPEGMCUHeightInPixels(self);
	return (JPEGHeightInPixels(self)+mcuheight-1)/mcuheight;
}


#endif
