#include "LZSS.h"

#include <stdlib.h>
#include <string.h>

bool InitializeLZSS(LZSS *self,size_t windowsize)
{
	self->window=malloc(windowsize);
	if(!self->window) return false;

	self->mask=windowsize-1; // Assume windows are power-of-two sized!

	RestartLZSS(self);

	return true;
}

void CleanupLZSS(LZSS *self)
{
	free(self->window);
}

void RestartLZSS(LZSS *self)
{
	memset(self->window,0,LZSSWindowSize(self));
	self->position=0;
}

void CopyBytesFromLZSSWindow(LZSS *self,uint8_t *buffer,int64_t startpos,int length)
{
	size_t windowoffs=LZSSWindowOffsetForPosition(self,startpos);

	if(windowoffs+length<=LZSSWindowSize(self)) // Request fits inside window
	{
		memcpy(buffer,&self->window[windowoffs],length);
	}
	else // Request wraps around window
	{
		size_t firstpart=LZSSWindowSize(self)-windowoffs;
		memcpy(&buffer[0],&self->window[windowoffs],firstpart);
		memcpy(&buffer[firstpart],&self->window[0],length-firstpart);
	}
}
