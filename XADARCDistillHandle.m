#import "XADARCDistillHandle.h"
#import "XADException.h"

@implementation XADARCDistillHandle

-(id)initWithHandle:(CSHandle *)handle
{
	return [self initWithHandle:handle length:CSHandleMaxLength];
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length
{
	if(self=[super initWithHandle:handle length:length windowSize:2048])
	{
		code=nil;
	}
	return self;
}

-(void)dealloc
{
	[code release];
	[super dealloc];
}

-(void)resetLZSSHandle
{
}

-(void)expandFromPosition:(off_t)pos
{
	while(XADLZSSShouldKeepExpanding(self))
	{
/*		int symbol=CSInputNextSymbolUsingCodeLE(input,code);

		if(symbol<256)
		{
			XADEmitLZSSLiteral(self,0,&pos);
		}
		else if(symbol==256)
		{
			[self endLZSSHandle];
			return;
		}
		else
		{
		}
*/
		XADEmitLZSSLiteral(self,0,&pos);
	}
}

@end

