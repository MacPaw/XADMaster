#import "CSBlockStreamHandle.h"

#include <openssl/des.h>

@interface XADStuffItDESHandle:CSBlockStreamHandle
{
	DES_cblock block;
	DES_LONG A,B,C,D;
}

+(NSData *)keyForPasswordData:(NSData *)passworddata entryKey:(NSData *)entrykey MKey:(NSData *)mkey;

-(id)initWithHandle:(CSHandle *)handle key:(NSData *)keydata;
-(id)initWithHandle:(CSHandle *)handle length:(off_t)length key:(NSData *)keydata;

-(int)produceBlockAtOffset:(off_t)pos;

@end
