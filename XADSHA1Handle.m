#import "XADSHA1Handle.h"

@implementation XADSHA1Handle

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length correctDigest:(NSData *)correctdigest;
{
	if((self=[super initWithName:[handle name] length:length]))
	{
		parent=[handle retain];
		digest=[correctdigest retain];
	}
	return self;
}

-(void)dealloc
{
	[parent release];
	[digest release];
	[super dealloc];
}

-(void)resetStream
{
	SHA1_Init(&context);
	[parent seekToFileOffset:0];
}

-(int)streamAtMost:(int)num toBuffer:(void *)buffer
{
	int actual=[parent readAtMost:num toBuffer:buffer];
	SHA1_Update(&context,buffer,actual);
	return actual;
}

-(BOOL)hasChecksum { return YES; }

-(BOOL)isChecksumCorrect
{
	if([digest length]!=20) return NO;

	SHA_CTX copy;
	copy=context;

	uint8_t buf[20];
	SHA1_Final(buf,&copy);

	return memcmp([digest bytes],buf,20)==0;
}

-(double)estimatedProgress { return [parent estimatedProgress]; }

@end


