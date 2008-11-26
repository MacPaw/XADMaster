#import "CSBlockStreamHandle.h"

@interface XADRARHandle:CSBlockStreamHandle
{
	CSHandle *sourcehandle;
	off_t startoffs;

	int method;

	void *ioptr,*unpackptr;
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length version:(int)version;
-(void)dealloc;

-(void)resetBlockStream;
-(int)produceBlockAtOffset:(off_t)pos;

-(CSHandle *)sourceHandle;
-(void)receiveBlock:(void *)block length:(int)length;

@end
