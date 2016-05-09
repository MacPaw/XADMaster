#import "CSStreamHandle.h"
#import "Checksums.h"
#import "Progress.h"

@interface XADXORSumHandle:CSStreamHandle
{
	uint8_t correctchecksum,checksum;
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length correctChecksum:(uint8_t)correct;

-(void)resetStream;
-(int)streamAtMost:(int)num toBuffer:(void *)buffer;

-(BOOL)hasChecksum;
-(BOOL)isChecksumCorrect;

@end
