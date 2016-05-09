#import "CSByteStreamHandle.h"

@interface XADStuffItXX86Handle:CSByteStreamHandle
{
	off_t lasthit;
	uint32_t bitfield;

	int numbufferbytes,currbufferbyte;
	uint8_t buffer[4];
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length;

-(void)resetByteStream;
-(uint8_t)produceByteAtOffset:(off_t)pos;

@end

