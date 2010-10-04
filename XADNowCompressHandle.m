#import "XADNowCompressHandle.h"
#import "XADException.h"

static void CopyBytesWithRepeat(uint8_t *dest,uint8_t *src,int length)
{
	for(int i=0;i<length;i++) dest[i]=src[i];
}

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

	off_t datastart=[parent readUInt32BE];

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

	NSLog(@"%x",[parent readUInt32BE]);

	nextblock=0;

	[self setBlockPointer:outblock];
}

-(int)produceBlockAtOffset:(off_t)pos
{
	if(nextblock>=numblocks) return 0;

	[parent seekToFileOffset:blocks[nextblock].offs];

	uint32_t length=blocks[nextblock+1].offs-blocks[nextblock].offs;
	int flags=blocks[nextblock].flags;
	int padding=blocks[nextblock].padding;
	nextblock++;

	if(length>sizeof(inblock)) [XADException raiseDecrunchException];

	[parent readBytes:length toBuffer:inblock];

			memcpy(outblock,inblock,length);
			return length;

	if(flags&0x20)
	{
		if(flags&0x1f)
		{
			// huffman + lzss
		}
		else
		{
			// huffman?
		}
	}
	else if(flags&0x40)
	{
		[XADException raiseNotSupportedException];
	}
	else
	{
		if(flags&0x1f)
		{
			// lzss
		}
		else
		{
			memcpy(outblock,inblock,length);
			return length;
		}
	}

	return 1;

/*	uint8_t headxor=0;

	int compsize=CSInputNextUInt16BE(input);
	//if(compsize>0x2000) [XADException raiseIllegalDataException];
	headxor^=compsize^(compsize>>8);

	int uncompsize=CSInputNextUInt16BE(input);
	if(uncompsize>0x2000) [XADException raiseIllegalDataException];
	headxor^=uncompsize^(uncompsize>>8);

	for(int i=0;i<4;i++) headxor^=CSInputNextByte(input);

	int datacorrectxor=CSInputNextByte(input);
	headxor^=datacorrectxor;

	int flags=CSInputNextByte(input);
	headxor^=flags;

	headxor^=CSInputNextByte(input);

	int headcorrectxor=CSInputNextByte(input);
	if(headxor!=headcorrectxor) [XADException raiseIllegalDataException];

	off_t nextblock=CSInputBufferOffset(input)+compsize;

	if(flags&1)
	{
		// Uncompressed block
		for(int i=0;i<uncompsize;i++) outbuffer[i]=CSInputNextByte(input);
	}
	else
	{
		int currpos=0;
		while(currpos<uncompsize)
		{
			int ismatch=CSInputNextBit(input);

			if(!ismatch) outbuffer[currpos++]=CSInputNextBitString(input,8);
			else
			{
				int isfar=CSInputNextBit(input);
				int offset=CSInputNextBitString(input,isfar?12:8);
				if(offset>currpos) [XADException raiseIllegalDataException];

				int length;
				if(CSInputNextBit(input)==0) length=2;
				else
				{
					if(CSInputNextBit(input)==0)
					{
						if(CSInputNextBit(input)==0) length=3;
						else length=4;
					}
					else length=CSInputNextBitString(input,4)+5;
				}

				if(currpos+length>uncompsize) length=uncompsize-currpos;
				if(length>offset) [XADException raiseIllegalDataException];

				CopyBytesWithRepeat(&outbuffer[currpos],&outbuffer[currpos-offset],length);
				currpos+=length;
			}
		}
	}

	CSInputSeekToBufferOffset(input,nextblock);

	[self setBlockPointer:outbuffer];
	return uncompsize;
	*/
}

@end
