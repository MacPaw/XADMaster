#import "XADRARAESHandle.h"

#import <openssl/sha.h>

@implementation XADRARAESHandle

-(id)initWithHandle:(CSHandle *)handle password:(NSString *)pass
{
	if(self=[super initWithName:[handle name]])
	{
		password=[pass retain];
	}
	return self;
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length password:(NSString *)pass
{
	if(self=[super initWithName:[handle name] length:length])
	{
		password=[pass retain];
	}
	return self;
}

-(void)dealloc
{
	[password release];
	[super dealloc];
}

-(void)resetBlockStream
{
	[self setBlockPointer:outblock];
}

-(int)produceBlockAtOffset:(off_t)pos
{
//	AES_encrypt(inblock,outblock,&key);

	return -1;
}

@end
