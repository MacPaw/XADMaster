#import "CSBlockStreamHandle.h"

@interface XADMSZipHandle:CSBlockStreamHandle
{
	CSHandle *parent;
	off_t startoffs;
	uint8_t *buffer;
}

-(id)initWithHandle:(CSHandle *)handle;
-(void)dealloc;

-(void)resetBlockStream;
-(int)produceBlockAtOffset:(off_t)pos;

@end
