#import "XADQuantumHandle.h"
#import "XADException.h"

@implementation XADQuantumHandle

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length
{
	if(self=[super initWithHandle:handle length:length windowSize:1024])
	{
	}
	return self;
}

-(void)dealloc
{
	[super dealloc];
}

-(void)resetLZSSHandle
{
}

-(int)nextLiteralOrOffset:(int *)offset andLength:(int *)length atPosition:(off_t)pos
{
}

@end
