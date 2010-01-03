#import "CSBlockStreamHandle.h"

@interface XADDiskDoublerDDnHandle:CSBlockStreamHandle
{
	uint8_t outbuffer[102400]; int xor;
}

-(int)produceBlockAtOffset:(off_t)pos;

@end
