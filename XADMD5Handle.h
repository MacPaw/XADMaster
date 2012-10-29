#import "CSStreamHandle.h"
#import "Checksums.h"
#import "Progress.h"

#include "Crypto/md5.h"

@interface XADMD5Handle:CSStreamHandle
{
	CSHandle *parent;
	NSData *digest;

	MD5_CTX context;
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length correctDigest:(NSData *)correctdigest;
-(void)dealloc;

-(void)resetStream;
-(int)streamAtMost:(int)num toBuffer:(void *)buffer;

-(BOOL)hasChecksum;
-(BOOL)isChecksumCorrect;

-(double)estimatedProgress;

@end

