#import "XADRARAESHandle.h"
#import "RARBug.h"

#import "Crypto/sha.h"

@implementation XADRARAESHandle

+(NSData *)keyForPassword:(NSString *)password salt:(NSData *)salt brokenHash:(BOOL)brokenhash
{
	uint8_t keybuf[2*16];

	int length=[password length];
	if(length>126) length=126;

	uint8_t passbuf[length*2+8];
	for(int i=0;i<length;i++)
	{
		int c=[password characterAtIndex:i];
		passbuf[2*i]=c;
		passbuf[2*i+1]=c>>8;
	}

	int buflength=length*2;

	if(salt)
	{
		memcpy(passbuf+2*length,[salt bytes],8);
		buflength+=8;
	}

	SHA_CTX sha;
	SHA1_Init(&sha);

	for(int i=0;i<0x40000;i++)
	{
		SHA1_Update_WithRARBug(&sha,passbuf,buflength,brokenhash);

		uint8_t num[3]={i,i>>8,i>>16};
		SHA1_Update_WithRARBug(&sha,num,3,brokenhash);

		if(i%0x4000==0)
		{
			SHA_CTX tmpsha=sha;
			uint8_t digest[20];
			SHA1_Final(digest,&tmpsha);
			keybuf[i/0x4000]=digest[19];
		}
	}

	uint8_t digest[20];
	SHA1_Final(digest,&sha);

	for(int i=0;i<16;i++) keybuf[i+16]=digest[i^3];

/*NSLog(@"%@",salt);
NSLog(@"%02x%02x%02x%02x %02x%02x%02x%02x %02x%02x%02x%02x %02x%02x%02x%02x",
keybuf[0],keybuf[1],keybuf[2],keybuf[3],keybuf[4],keybuf[5],keybuf[6],keybuf[7],
keybuf[8],keybuf[9],keybuf[10],keybuf[11],keybuf[12],keybuf[13],keybuf[14],keybuf[15]
);*/

	return [NSData dataWithBytes:keybuf length:sizeof(keybuf)];
}

-(id)initWithHandle:(CSHandle *)handle key:(NSData *)keydata
{
	return [self initWithHandle:handle length:CSHandleMaxLength key:keydata];
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length key:(NSData *)keydata
{
	if((self=[super initWithName:[handle name] length:length]))
	{
		parent=[handle retain];
		startoffs=[handle offsetInFile];

		const uint8_t *keybytes=[keydata bytes];
		memcpy(iv,&keybytes[0],16);
		aes_decrypt_key128(&keybytes[16],&aes);
	}
	return self;
}

-(id)initWithHandle:(CSHandle *)handle RAR5Key:(NSData *)keydata IV:(NSData *)ivdata
{
	return [self initWithHandle:handle length:CSHandleMaxLength RAR5Key:keydata IV:ivdata];
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length RAR5Key:(NSData *)keydata IV:(NSData *)ivdata
{
	if((self=[super initWithName:[handle name] length:length]))
	{
		parent=[handle retain];
		startoffs=[handle offsetInFile];

		memcpy(iv,[ivdata bytes],16);
		aes_decrypt_key256([keydata bytes],&aes);
	}
	return self;
}

-(void)dealloc
{
	[parent release];
	[super dealloc];
}

-(void)resetBlockStream
{
	[parent seekToFileOffset:startoffs];
	[self setBlockPointer:buffer];
	memcpy(block,iv,sizeof(iv));
}

-(int)produceBlockAtOffset:(off_t)pos
{
	int actual=[parent readAtMost:sizeof(buffer) toBuffer:buffer];
	if(actual==0) return -1;

	aes_cbc_decrypt(buffer,buffer,actual&~15,block,&aes);

	return actual;
}

@end
