#import "CSBlockStreamHandle.h"

@interface XADDiskDoublerADnHandle:CSBlockStreamHandle
{
	uint8_t outbuffer[8192];
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length;

-(int)produceBlockAtOffset:(off_t)pos;

@end
