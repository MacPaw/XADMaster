#import "CSHandle.h"

@interface CSStreamHandle:CSHandle
{
	off_t streampos,streamlength;
	BOOL needsreset,endofstream;
	int nextstreambyte;
}

-(id)initWithName:(NSString *)descname;
-(id)initWithName:(NSString *)descname length:(off_t)length;
-(id)initAsCopyOf:(CSStreamHandle *)other;

-(off_t)fileSize;
-(off_t)offsetInFile;
-(BOOL)atEndOfFile;
-(void)seekToFileOffset:(off_t)offs;
-(int)readAtMost:(int)num toBuffer:(void *)buffer;

-(void)resetStream;
-(int)streamAtMost:(int)num toBuffer:(void *)buffer;

-(void)endStream;

@end
