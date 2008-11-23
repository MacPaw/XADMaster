#import "CSStreamHandle.h"

@interface CSByteStreamHandle:CSStreamHandle
{
	uint8_t (*bytestreamproducebyte_ptr)(id,SEL,off_t);
}

-(id)initWithName:(NSString *)descname length:(off_t)length;
-(id)initWithHandle:(CSHandle *)handle length:(off_t)length bufferSize:(int)buffersize;
-(id)initAsCopyOf:(CSByteStreamHandle *)other;

-(int)streamAtMost:(int)num toBuffer:(void *)buffer;
-(void)resetStream;

-(void)resetByteStream;
-(uint8_t)produceByteAtOffset:(off_t)pos;

@end



extern NSString *CSByteStreamEOFReachedException;

static inline void CSByteStreamEOF() { [NSException raise:CSByteStreamEOFReachedException format:@""]; }
