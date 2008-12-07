#import "CSBlockStreamHandle.h"
#import "RARUnpacker.h"

@interface XADRARHandle:CSBlockStreamHandle
{
	CSHandle *sourcehandle;
	off_t startoffs;

	int method;

	RARUnpacker *unpacker;
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length version:(int)version;
-(void)dealloc;

-(void)resetBlockStream;
-(int)produceBlockAtOffset:(off_t)pos;

@end
