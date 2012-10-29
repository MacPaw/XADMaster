#import "XADMD5Handle.h"

@implementation XADMD5Handle

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
	MD5_Init(&context);
	[parent seekToFileOffset:0];
}

-(int)streamAtMost:(int)num toBuffer:(void *)buffer
{
	int actual=[parent readAtMost:num toBuffer:buffer];
	MD5_Update(&context,buffer,actual);
	return actual;
}

-(BOOL)hasChecksum { return YES; }

-(BOOL)isChecksumCorrect
{
	if([digest length]!=16) return NO;

	MD5_CTX copy;
	copy=context;

	uint8_t buf[16];
	MD5_Final(buf,&copy);

	return memcmp([digest bytes],buf,16)==0;
}

-(double)estimatedProgress { return [parent estimatedProgress]; }

@end


