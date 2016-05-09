#import "XADXORSumHandle.h"

@implementation XADXORSumHandle

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length correctChecksum:(uint8_t)correct
{
	if((self=[super initWithParentHandle:handle length:length]))
	{
		correctchecksum=correct;
	}
	return self;
}

-(void)resetStream
{
	[parent seekToFileOffset:0];
	checksum=0;
}

-(int)streamAtMost:(int)num toBuffer:(void *)buffer
{
	int actual=[parent readAtMost:num toBuffer:buffer];

	uint8_t *bytes=buffer;
	for(int i=0;i<actual;i++) checksum^=bytes[i];

	return actual;
}

-(BOOL)hasChecksum { return YES; }

-(BOOL)isChecksumCorrect
{
	return checksum==correctchecksum;
}

-(double)estimatedProgress { return [parent estimatedProgress]; }

@end

