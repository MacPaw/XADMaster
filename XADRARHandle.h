#import "CSBlockStreamHandle.h"
#import "RARUnpacker.h"

@class XADRARParts;

@interface XADRARHandle:CSBlockStreamHandle
{
	CSHandle *sourcehandle;
	XADRARParts *p;
	int method;

	RARUnpacker *unpacker;

	int part;
	off_t bytesdone;
}

-(id)initWithHandle:(CSHandle *)handle parts:(XADRARParts *)parts version:(int)version;
-(void)dealloc;

-(void)resetBlockStream;
-(int)produceBlockAtOffset:(off_t)pos;

-(int)provideInput:(int)length buffer:(void *)buffer;

@end

@interface XADRARParts:NSObject
{
	@public
	int numparts;
	struct { off_t start,end,length; } *parts;
}

+(XADRARParts *)partWithStart:(off_t)start compressedSize:(off_t)compsize uncompressedSize:(off_t)size;

-(id)init;
-(void)dealloc;

-(void)addPartFrom:(off_t)fileoffset compressedSize:(off_t)compsize uncompressedSize:(off_t)size;

-(int)count;
-(off_t)outputStartOffsetForPart:(int)part;
-(off_t)outputSizeForPart:(int)part;

@end
