#import "XADStuffItXX86Handle.h"
#import "XADException.h"

@implementation XADStuffItXX86Handle

-(void)resetByteStream
{
	lasthit=-6;
	bitfield=0;

	numbufferbytes=0;
	currbufferbyte=0;
}

-(uint8_t)produceByteAtOffset:(off_t)pos
{
	if(currbufferbyte<numbufferbytes) return buffer[currbufferbyte++];

	if(CSInputAtEOF(input)) CSByteStreamEOF(self);

	uint8_t b=CSInputNextByte(input);

	if(b==0xe8||b==0xe9)
	{
		if(pos-lasthit>5)
		{
			bitfield=0;
		}
		else
		{
			int n=pos-lasthit;
			while(n--)
			{
				bitfield=(bitfield&0x77)<<1;
			}
		}

		// Read offset into buffer.
		for(int i=0;i<4;i++)
		{
/*			if(CSInputAtEOF(input))
			{
				currbufferbyte=0;
				numbufferbytes=i;
				return b;
			}*/

			buffer[i]=CSInputPeekByte(input,i);
		}

		// Check if the offset is within 16 megabytes forward or back.
		if(buffer[3]==0x00 || buffer[3]==0xff)
		{
if(1)
//			if(table[(bitfield>>1)&0x07]!=0 && (bitfield>>1)<=0x0f)
			{
				int32_t absaddress=CSInt32LE(buffer);
				int32_t reladdress=absaddress-pos-6;

//				...

				CSSetInt32LE(buffer,reladdress);
				currbufferbyte=0;
				numbufferbytes=4;

				CSInputSkipBytes(input,4);
			}
			else
			{
				bitfield|=0x11;
			}
		}
		else
		{
			bitfield|=0x01;
		}
	}

	return b;
}

@end
