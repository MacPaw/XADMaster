#import "XADNowCompressHandle.h"
#import "XADException.h"
#import "XADPrefixCode.h"

static int UnpackHuffman(uint8_t *sourcestart,uint8_t *sourceend,
uint8_t *destinationstart,uint8_t *destinationend);
static int UnpackLZSS(uint8_t *sourcestart,uint8_t *sourceend,
uint8_t *destinationstart,uint8_t *destinationend);

static XADPrefixCode *AllocAndReadCode(uint8_t *source,uint8_t *sourceend,int numentries,uint8_t **newsource);
static void CopyBytesWithRepeat(uint8_t *dest,uint8_t *src,int length);

@implementation XADNowCompressHandle

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length
{
	if(self=[super initWithName:[handle name] length:length])
	{
		parent=[handle retain];
		startoffset=[handle offsetInFile];
		blocks=NULL;
	}
	return self;
}

-(void)dealloc
{
	free(blocks);
	[parent release];
	[super dealloc];
}

-(void)resetBlockStream
{
	[parent seekToFileOffset:startoffset];

	uint32_t datastart=[parent readUInt32BE];

	int numentries=(datastart-startoffset-12)/8;

	numblocks=numentries-1;

	free(blocks);
	blocks=malloc(numentries*sizeof(blocks[0]));

	NSLog(@"%x",datastart);
	NSLog(@"%x",[parent readUInt32BE]);

	for(int i=0;i<numentries;i++)
	{
		blocks[i].offs=[parent readUInt32BE];
		blocks[i].flags=[parent readUInt16BE];
		blocks[i].padding=[parent readUInt16BE];

		NSLog(@"%08x %04x %04x",blocks[i].offs,blocks[i].flags,blocks[i].padding);
	}

	nextblock=0;

	[self setBlockPointer:outblock];
}

-(int)produceBlockAtOffset:(off_t)pos
{
	if(nextblock>=numblocks) return 0;

	[parent seekToFileOffset:blocks[nextblock].offs];

	int flags=blocks[nextblock].flags;
	int padding=blocks[nextblock].padding;
	uint32_t length=blocks[nextblock+1].offs-blocks[nextblock].offs-padding-4;
	nextblock++;

	if(length>sizeof(inblock)) [XADException raiseDecrunchException];

	if(flags&0x20)
	{
		if(flags&0x1f) // LZSS and Huffman.
		{
			[parent readBytes:length toBuffer:outblock];

			int outlength1=UnpackHuffman(outblock,outblock+length,inblock,inblock+sizeof(inblock));
			if(!outlength1) [XADException raiseDecrunchException];

			int outlength2=UnpackLZSS(inblock,inblock+outlength1,outblock,outblock+sizeof(outblock));
			if(!outlength2) [XADException raiseDecrunchException];

			return outlength2;
		}
		else // Huffman only.
		{
			[parent readBytes:length toBuffer:inblock];

			int outlength=UnpackHuffman(inblock,inblock+length,outblock,outblock+sizeof(outblock));
			if(!outlength) [XADException raiseDecrunchException];

			return outlength;
		}
	}
	else if(flags&0x40) // ?
	{
		[XADException raiseNotSupportedException];
	}
	else
	{
		if(flags&0x1f) // LZSS only.
		{
			[parent readBytes:length toBuffer:inblock];

			int outlength=UnpackLZSS(inblock,inblock+length,outblock,outblock+sizeof(outblock));
			if(!outlength) [XADException raiseDecrunchException];

			return outlength;
		}
		else // No compression.
		{
			[parent readBytes:length toBuffer:outblock];
			return length;
		}
	}

	return 1;
}

@end

static int UnpackHuffman(uint8_t *sourcestart,uint8_t *sourceend,
uint8_t *destinationstart,uint8_t *destinationend)
{
	uint8_t *source=sourcestart;

	if(source>=sourceend) [XADException raiseDecrunchException];//return 0;
	int endbits=*source++;

	XADPrefixCode *code=AllocAndReadCode(source,sourceend,256,&source);
	if(!code) return 0;

	CSInputBuffer *buf=CSInputBufferAllocWithBuffer(source,sourceend-source,0);

	int numbits=(sourceend-source)*8;
	if(endbits) numbits-=16-endbits;

	uint8_t *destination=destinationstart;
	while(CSInputBufferBitOffset(buf)<numbits)
	{
		if(destination>=destinationend) [XADException raiseDecrunchException];//return 0;
		*destination++=CSInputNextSymbolUsingCode(buf,code);
	}

	if(CSInputBufferBitOffset(buf)!=numbits) [XADException raiseDecrunchException];//return 0;

	[code release];

	return destination-destinationstart;
}

static int UnpackLZSS(uint8_t *sourcestart,uint8_t *sourceend,
uint8_t *destinationstart,uint8_t *destinationend)
{
	uint8_t *source=sourcestart+2;
	uint8_t *destination=destinationstart;

	int bits,numbits=0;
	while(source<sourceend)
	{
		if(!numbits)
		{
			bits=*source++;
			numbits=8;
		}

		if(bits&0x80)
		{
			if(destination>=destinationend) [XADException raiseDecrunchException];//return 0;
			*destination++=*source++;
		}
		else
		{
			int b1=*source++;
			int b2=*source++;

			int offset=((b1&0xf8)<<5)|b2;

			int length=b1&0x07;
			if(!length) length=*source++;
			length+=2;

			if(destination-offset<destinationstart) [XADException raiseDecrunchException];//return 0;

			for(int i=0;i<length;i++)
			{
				if(destination>=destinationend) [XADException raiseDecrunchException];//return 0;
				destination[0]=destination[-offset];
				destination++;
			}
		}

		bits<<=1;
		numbits--;
	}

	return destination-destinationstart;
}

static XADPrefixCode *AllocAndReadCode(uint8_t *sourcestart,uint8_t *sourceend,int numentries,uint8_t **newsource)
{
	uint8_t *source=sourcestart;

	int lengths[numentries];
	for(int i=0;i<numentries/2;i++)
	{
		if(source>=sourceend) return 0;
		uint8_t val=*source++;

		lengths[2*i]=val>>4;
		lengths[2*i+1]=val&0x0f;
	}

	if(source>=sourceend) return 0;
	int extralengths=*source++;
	for(int i=0;i<extralengths;i++)
	{
		if(source>=sourceend) return 0;
		lengths[*source++]+=16;
	}

	// TODO: padding?

	if(newsource) *newsource=source;

	return [[XADPrefixCode alloc] initWithLengths:lengths numberOfSymbols:numentries
	maximumLength:32 shortestCodeIsZeros:YES];
}

static void CopyBytesWithRepeat(uint8_t *dest,uint8_t *src,int length)
{
	for(int i=0;i<length;i++) dest[i]=src[i];
}
