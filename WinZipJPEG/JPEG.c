#include "JPEG.h"

#include <stdio.h>
#include <string.h>

static const uint8_t *FindNextMarker(const uint8_t *ptr,const uint8_t *end);
static int ParseSize(const uint8_t *ptr,const uint8_t *end);

static inline uint16_t ParseUInt16(const uint8_t *ptr) { return (ptr[0]<<8)|ptr[1]; }

const void *FindStartOfWinZipJPEGImage(const void *bytes,size_t length)
{
	const uint8_t *ptr=bytes;
	const uint8_t *end=ptr+length;

	while(ptr+2<=end)
	{
		if(ptr[0]==0xff && ptr[1]==0xd8) return ptr;
		ptr++;
	}

	return NULL;
}

void InitializeWinZipJPEGMetadata(WinZipJPEGMetadata *self)
{
	memset(self,0,sizeof(*self));
}

int ParseWinZipJPEGMetadata(WinZipJPEGMetadata *self,const void *bytes,size_t length)
{
	const uint8_t *ptr=bytes;
	const uint8_t *end=ptr+length;

	for(;;)
	{
		ptr=FindNextMarker(ptr,end);
		if(!ptr) return WinZipJPEGMetadataParsingFailed;

		switch(*ptr++)
		{
			case 0xd8: // Start of image
fprintf(stderr,"Start of image\n");
				// Empty marker, do nothing.
			break;

			case 0xc4: // Define huffman table
			{
				int size=ParseSize(ptr,end);
				if(!size) return WinZipJPEGMetadataParsingFailed;
				const uint8_t *next=ptr+size;

				ptr+=2;

fprintf(stderr,"Define huffman table(s)\n");
				while(ptr+17<=next)
				{
					int class=*ptr>>4;
					int index=*ptr&0x0f;
					ptr++;

					if(class!=0 && class!=1) return WinZipJPEGMetadataParsingFailed;
					if(index>=4) return WinZipJPEGMetadataParsingFailed;

					int numcodes[16];
					int totalcodes=0;
					for(int i=0;i<16;i++)
					{
						numcodes[i]=ptr[i];
						totalcodes+=numcodes[i];
					}
					ptr+=16;

					if(ptr+totalcodes>next) return WinZipJPEGMetadataParsingFailed;

fprintf(stderr," > %s table at %d with %d codes\n",class==0?"DC":"AC",index,totalcodes);

					unsigned int code=0;
					for(int i=0;i<16;i++)
					{
						for(int j=0;j<numcodes[i];j++)
						{
							int value=*ptr++;

							self->huffmantables[class][index].codes[value].code=code;
							self->huffmantables[class][index].codes[value].length=i+1;

							code++;
						}

						code<<=1;
					}
				}

				ptr=next;
			}
			break;

			case 0xdb: // Define quantization table(s)
			{
				int size=ParseSize(ptr,end);
				if(!size) return WinZipJPEGMetadataParsingFailed;
				const uint8_t *next=ptr+size;

				ptr+=2;

fprintf(stderr,"Define quantization table(s)\n");
				while(ptr+1<=next)
				{
					int precision=*ptr>>4;
					int index=*ptr&0x0f;
					ptr++;

					if(index>=4) return WinZipJPEGMetadataParsingFailed;

					if(precision==0)
					{
fprintf(stderr," > 8 bit table at %d\n",index);
						if(ptr+64>next) return WinZipJPEGMetadataParsingFailed;
						for(int i=0;i<64;i++) self->quantizationtables[index].c[i]=ptr[i];
						ptr+=64;
					}
					else if(precision==1)
					{
fprintf(stderr," > 16 bit table at %d\n",index);
						if(ptr+128>next) return WinZipJPEGMetadataParsingFailed;
						for(int i=0;i<64;i++) self->quantizationtables[index].c[i]=ParseUInt16(&ptr[2*i]);
						ptr+=128;
					}
					else return WinZipJPEGMetadataParsingFailed;
				}

				ptr=next;
			}
			break;

			case 0xdd: // Define restart interval
			{
				int size=ParseSize(ptr,end);
				if(!size) return WinZipJPEGMetadataParsingFailed;
				const uint8_t *next=ptr+size;

				self->restartinterval=ParseUInt16(&ptr[2]);

				ptr=next;
fprintf(stderr,"Define restart interval: %d\n",self->restartinterval);
			}
			break;

			case 0xc0: // Start of frame 0
			case 0xc1: // Start of frame 1
			{
				int size=ParseSize(ptr,end);
				if(!size) return WinZipJPEGMetadataParsingFailed;
				const uint8_t *next=ptr+size;

				if(size<8) return WinZipJPEGMetadataParsingFailed;
				self->bits=ptr[2];
				self->height=ParseUInt16(&ptr[3]);
				self->width=ParseUInt16(&ptr[5]);
				self->numcomponents=ptr[7];

				if(self->numcomponents<1 || self->numcomponents>4) return WinZipJPEGMetadataParsingFailed;
				if(size<8+self->numcomponents*3) return WinZipJPEGMetadataParsingFailed;

				self->maxhorizontalfactor=1;
				self->maxverticalfactor=1;

fprintf(stderr,"Start of frame: %dx%d %d bits %d comps\n",self->width,self->height,self->bits,self->numcomponents);
				for(int i=0;i<self->numcomponents;i++)
				{
					self->components[i].identifier=ptr[8+i*3];
					self->components[i].horizontalfactor=ptr[9+i*3]>>4;
					self->components[i].verticalfactor=ptr[9+i*3]&0x0f;
					self->components[i].quantizationtable=ptr[10+i*3];

					if(self->components[i].horizontalfactor>self->maxhorizontalfactor)
					self->maxhorizontalfactor=self->components[i].horizontalfactor;

					if(self->components[i].verticalfactor>self->maxverticalfactor)
					self->maxverticalfactor=self->components[i].verticalfactor;
fprintf(stderr," > Component id %d, %dx%d, quant %d\n",
self->components[i].identifier=ptr[8+i*3],
self->components[i].horizontalfactor,self->components[i].verticalfactor,
self->components[i].quantizationtable);
				}

				ptr=next;
			}
			break;

			case 0xda: // Start of scan
			{
				int size=ParseSize(ptr,end);
				if(!size) return WinZipJPEGMetadataParsingFailed;

				if(size<6) return WinZipJPEGMetadataParsingFailed;

				self->numscancomponents=ptr[2];
				if(self->numscancomponents<1 || self->numscancomponents>4) return WinZipJPEGMetadataParsingFailed;
				if(size<6+self->numscancomponents*2) return WinZipJPEGMetadataParsingFailed;

				for(int i=0;i<self->numscancomponents;i++)
				{
					int identifier=ptr[3+i*2];
					int index=-1;
					for(int j=0;j<self->numcomponents;j++)
					{
						if(self->components[j].identifier==identifier)
						{
							index=j;
							break;
						}
					}
					if(index==-1) return WinZipJPEGMetadataParsingFailed;

					self->scancomponents[i].componentindex=index;

					self->scancomponents[i].dctable=ptr[4+i*2]>>4;
					self->scancomponents[i].actable=ptr[4+i*2]&0x0f;
				}

				if(ptr[3+self->numscancomponents*2]!=0) return WinZipJPEGMetadataParsingFailed;
				if(ptr[4+self->numscancomponents*2]!=63) return WinZipJPEGMetadataParsingFailed;
				if(ptr[5+self->numscancomponents*2]!=0) return WinZipJPEGMetadataParsingFailed;

fprintf(stderr,"Start of scan: %d comps\n",self->numscancomponents,ptr[3+self->numscancomponents*2]);

				return WinZipJPEGMetadataFoundStartOfScan;
			}
			break;


			case 0xd9: // End of image
				return WinZipJPEGMetadataFoundEndOfImage;

			default:
			{
fprintf(stderr,"Unknown marker %02x\n",ptr[-1]);
				int size=ParseSize(ptr,end);
				if(!size) return WinZipJPEGMetadataParsingFailed;
				ptr+=size;
			}
			break;
		}
	}
}

// Find next marker, skipping pad bytes.
static const uint8_t *FindNextMarker(const uint8_t *ptr,const uint8_t *end)
{
	if(ptr>=end) return NULL;
	if(*ptr!=0xff) return NULL;

	while(*ptr==0xff)
	{
		ptr++;
		if(ptr>=end) return NULL;
	}

	return ptr;
}

// Parse and sanity check the size of a marker.
static int ParseSize(const uint8_t *ptr,const uint8_t *end)
{
	if(ptr+2>end) return 0;

	int size=ParseUInt16(ptr);
	if(size<2) return 0;
	if(ptr+size>end) return 0;

	return size;
}

