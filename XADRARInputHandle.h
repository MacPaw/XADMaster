#import "CSStreamHandle.h"

@interface XADRARInputHandle:CSStreamHandle
{
	CSHandle *handle;
	NSArray *parts;

	int part;
	off_t partend;

	uint32_t crc,correctcrc;
}

-(id)initWithHandle:(CSHandle *)parent parts:(NSArray *)partarray;
-(void)dealloc;

-(void)resetStream;
-(int)streamAtMost:(int)num toBuffer:(void *)buffer;

-(void)startNextPart;

@end
