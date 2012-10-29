#import "CSStreamHandle.h"
#import "Checksums.h"
#import "Progress.h"

#include "Crypto/sha.h"

@interface XADSHA1Handle:CSStreamHandle
{
	CSHandle *parent;
	NSData *digest;

	SHA_CTX context;
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length correctDigest:(NSData *)correctdigest;
-(void)dealloc;

-(void)resetStream;
-(int)streamAtMost:(int)num toBuffer:(void *)buffer;

-(BOOL)hasChecksum;
-(BOOL)isChecksumCorrect;

-(double)estimatedProgress;

@end

