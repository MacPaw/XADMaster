#import "CSBlockStreamHandle.h"
#import "RARUnpacker.h"

@class XADRARStream;

@interface XADRARHandle:CSBlockStreamHandle
{
	CSHandle *sourcehandle;
	XADRARStream *s;
	int method;

	RARUnpacker *unpacker;

	int part;
	off_t bytesdone;
}

-(id)initWithHandle:(CSHandle *)handle stream:(XADRARStream *)stream;
-(void)dealloc;

-(void)resetBlockStream;
-(int)produceBlockAtOffset:(off_t)pos;

-(int)provideInput:(int)length buffer:(void *)buffer;

@end

@interface XADRARStream:NSObject
{
	@public
	int method;
	int numparts;
	struct { off_t start,end,length; } *parts;
}

+(XADRARStream *)streamWithVersion:(int)version start:(off_t)start compressedSize:(off_t)compsize uncompressedSize:(off_t)size;

-(id)initWithVersion:(int)version;
-(void)dealloc;

-(void)addPartFrom:(off_t)fileoffset compressedSize:(off_t)compsize uncompressedSize:(off_t)size;

-(NSString *)description;

@end
