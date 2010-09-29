#import "XADStacLZSHandle.h"
#import "XADException.h"

// Not actually used. Implemented by mistake, and untested, but might work.

@implementation XADStacLZSHandle

-(id)initWithHandle:(CSHandle *)handle
{
	return [self initWithHandle:handle length:CSHandleMaxLength];
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length
{
	if(self=[super initWithHandle:handle length:length windowSize:2048])
	{
		lengthcode=[XADPrefixCode new];

		[lengthcode addValue:2 forCodeWithHighBitFirst:0x00 length:2];
		[lengthcode addValue:3 forCodeWithHighBitFirst:0x01 length:2];
		[lengthcode addValue:4 forCodeWithHighBitFirst:0x02 length:2];
		[lengthcode addValue:5 forCodeWithHighBitFirst:0x0c length:4];
		[lengthcode addValue:6 forCodeWithHighBitFirst:0x0d length:4];
		[lengthcode addValue:7 forCodeWithHighBitFirst:0x0e length:4];
		[lengthcode addValue:8 forCodeWithHighBitFirst:0x0f length:4];
	}
	return self;
}

-(void)dealloc
{
	[lengthcode release];
	[super dealloc];
}

-(void)expandFromPosition:(off_t)pos
{
	while(XADLZSSShouldKeepExpanding(self))
	{
		if(CSInputNextBit(input)==0)
		{
			int byte=CSInputNextBitString(input,8);
			XADEmitLZSSLiteral(self,byte,&pos);
		}
		else
		{
			int offset;
			if(CSInputNextBit(input)==1) offset=CSInputNextBitString(input,7);
			else
			{
				int offsethigh=CSInputNextBitString(input,7);
				if(offsethigh==0)
				{
					[self endLZSSHandle];
					return;
				}

				offset=(offsethigh<<4)|CSInputNextBitString(input,4);
				//offset=CSInputNextBitString(input,11);
			}

			int length=CSInputNextSymbolUsingCode(input,lengthcode);
			if(length==8)
			{
				for(;;)
				{
					int code=CSInputNextBitString(input,4);
					length+=code;

					if(code!=15) break;
				}
			}

			if(length>2048) [XADException raiseDecrunchException];

			XADEmitLZSSMatch(self,offset,length,&pos);
		}
	}
}

@end

