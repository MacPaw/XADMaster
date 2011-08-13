#include "Decompressor.h"

#ifdef __MINGW32__
#ifdef __STRICT_ANSI__
#undef __STRICT_ANSI__
#endif
#include <fcntl.h>
#endif

#include <stdio.h>

static size_t STDIOReadFunction(void *context,uint8_t *buffer,size_t length) { return fread(buffer,1,length,(FILE *)context); }

int main(int argv,const char **argc)
{
	#ifdef __MINGW32__
	setmode(fileno(stdin),O_BINARY);
	#endif

	WinZipJPEGDecompressor *decompressor=AllocWinZipJPEGDecompressor(STDIOReadFunction,stdin);
	if(!decompressor)
	{
		fprintf(stderr,"Failed to allocate decompressor.\n");
		return 1;
	}

	int error;

	error=ReadWinZipJPEGHeader(decompressor);
	if(error)
	{
		fprintf(stderr,"Error %d while trying to read header.\n",error);
		return 1;
	}

	while(!IsFinalWinZipJPEGBundle(decompressor))
	{
		error=ReadNextWinZipJPEGBundle(decompressor);
		if(error)
		{
			fprintf(stderr,"Error %d while trying to read next bundle.\n",error);
			return 1;
		}

		//printf("%d bytes of metadata.\n",WinZipJPEGBundleMetadataLength(decompressor));

TestDecompress(decompressor);

		//fwrite(WinZipJPEGBundleMetadataBytes(decompressor),1,WinZipJPEGBundleMetadataLength(decompressor),stdout);
	}

	FreeWinZipJPEGDecompressor(decompressor);

	return 0;
}

