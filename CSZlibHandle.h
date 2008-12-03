#import "CSHandle.h"

#include <zlib.h>

@interface CSZlibHandle:CSHandle
{
	CSHandle *fh;
	off_t startoffs;
	z_stream zs;
	BOOL inited,eof,seekback;
	//uint8_t inbuffer[128*1024];
	uint8_t inbuffer[16*1024];
}

+(CSZlibHandle *)zlibHandleWithHandle:(CSHandle *)handle;
+(CSZlibHandle *)zlibHandleWithHandle:(CSHandle *)handle length:(off_t)length;
+(CSZlibHandle *)deflateHandleWithHandle:(CSHandle *)handle;
+(CSZlibHandle *)deflateHandleWithHandle:(CSHandle *)handle length:(off_t)length;

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length header:(BOOL)header name:(NSString *)descname;
-(id)initAsCopyOf:(CSZlibHandle *)other;
-(void)dealloc;

-(void)setSeekBackAtEOF:(BOOL)seekateof;

-(off_t)offsetInFile;
-(BOOL)atEndOfFile;

-(void)seekToFileOffset:(off_t)offs;
-(void)seekToEndOfFile;
-(int)readAtMost:(int)num toBuffer:(void *)buffer;

-(void)_raiseZlib;

@end
