/*
 * JPEG.h
 *
 * Copyright (c) 2017-present, MacPaw Inc. All rights reserved.
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
 * MA 02110-1301  USA
 */
#ifndef __WINZIP_JPEG_JPEG_H__
#define __WINZIP_JPEG_JPEG_H__

#include <stdint.h>
#include <stdbool.h>
#include <stdlib.h>

#define WinZipJPEGMetadataFoundStartOfScan 1
#define WinZipJPEGMetadataFoundEndOfImage 2
#define WinZipJPEGMetadataParsingFailed 3

typedef struct WinZipJPEGBlock
{
	int16_t c[64];
	uint8_t eob;
} WinZipJPEGBlock;

typedef struct WinZipJPEGQuantizationTable
{
	int16_t c[64];
} WinZipJPEGQuantizationTable;

typedef struct WinZipJPEGHuffmanCode
{
	unsigned int code,length;
} WinZipJPEGHuffmanCode;

typedef struct WinZipJPEGHuffmanTable
{
	WinZipJPEGHuffmanCode codes[256];
} WinZipJPEGHuffmanTable;

typedef struct WinZipJPEGComponent
{
	unsigned int identifier;
	unsigned int horizontalfactor,verticalfactor;
	WinZipJPEGQuantizationTable *quantizationtable;
} WinZipJPEGComponent;

typedef struct WinZipJPEGScanComponent
{
	WinZipJPEGComponent *component;
	WinZipJPEGHuffmanTable *dctable,*actable;
} WinZipJPEGScanComponent;

typedef struct WinZipJPEGMetadata
{
	unsigned int width,height,bits;
	unsigned int restartinterval;

	unsigned int maxhorizontalfactor,maxverticalfactor;
	unsigned int horizontalmcus,verticalmcus;

	unsigned int numcomponents;
	WinZipJPEGComponent components[4];

	unsigned int numscancomponents;
	WinZipJPEGScanComponent scancomponents[4];

	WinZipJPEGQuantizationTable quantizationtables[4];
	WinZipJPEGHuffmanTable huffmantables[2][4];
} WinZipJPEGMetadata;

const void *FindStartOfWinZipJPEGImage(const void *bytes,size_t length);

void InitializeWinZipJPEGMetadata(WinZipJPEGMetadata *self);
int ParseWinZipJPEGMetadata(WinZipJPEGMetadata *self,const void *bytes,size_t length);

#endif
