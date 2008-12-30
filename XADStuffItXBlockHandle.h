#import "CSBlockStreamHandle.h"

@interface XADStuffItXBlockHandle:CSBlockStreamHandle
{
	CSHandle *parent;
	off_t startoffs;
	uint8_t buffer[65536];
}

-(id)initWithHandle:(CSHandle *)handle;
-(void)dealloc;

-(void)resetBlockStream;
-(int)produceBlockAtOffset:(off_t)pos;

@end
