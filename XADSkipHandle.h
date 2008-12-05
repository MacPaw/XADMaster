#import "CSHandle.h"

struct XADSkip
{
	off_t start,length;
} XADSkip;

static inline XADSkip XADMakeSkip(off_t start,off_t length) { XADSkip skip={start,length}; return skip; }

@interface XADSkipHandle:NSObject
{
	CSHandle *parent;
	XADSkip *skips;
	int numskips;
}

-(id)initWithHandle:(CSHandle *)handle;
-(id)initAsCopyOf:(XADSkipHandle *)other;
-(void)dealloc;

-(void)addSkipFrom:(off_t)start length:(off_t)length;
-(void)addSkipFrom:(off_t)start to:(off_t)end;

-(off_t)fileSize;
-(off_t)offsetInFile;
-(BOOL)atEndOfFile;

-(void)seekToFileOffset:(off_t)offs;
-(void)seekToEndOfFile;
-(int)readAtMost:(int)num toBuffer:(void *)buffer;

@end

/*
#import "CSHandle.h"

@interface CSMultiHandle:CSHandle
{
	NSArray *handles;
	int currhandle;
}

+(CSHandle *)multiHandleWithHandleArray:(NSArray *)handlearray;
+(CSHandle *)multiHandleWithHandles:(CSHandle *)firsthandle,...;

-(id)initWithHandles:(NSArray *)handlearray;
-(id)initAsCopyOf:(CSMultiHandle *)other;
-(void)dealloc;

-(NSArray *)handles;

-(off_t)fileSize;
-(off_t)offsetInFile;
-(BOOL)atEndOfFile;

-(void)seekToFileOffset:(off_t)offs;
-(void)seekToEndOfFile;
-(int)readAtMost:(int)num toBuffer:(void *)buffer;

@end
*/