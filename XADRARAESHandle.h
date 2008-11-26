#import "CSBlockStreamHandle.h"
#import <openssl/aes.h>

@interface XADRARAESHandle:CSBlockStreamHandle
{
	NSString *password;

	AES_KEY key;
	uint8_t iv[16],outblock[16];
}

-(id)initWithHandle:(CSHandle *)handle password:(NSString *)password;
-(id)initWithHandle:(CSHandle *)handle length:(off_t)length password:(NSString *)password;
-(void)dealloc;

-(void)resetBlockStream;
-(int)produceBlockAtOffset:(off_t)pos;

@end
