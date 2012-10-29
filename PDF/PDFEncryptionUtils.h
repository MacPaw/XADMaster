#import <Foundation/Foundation.h>
#import "../CSHandle.h"
#import "../CSBlockStreamHandle.h"
#import "../Crypto/md5.h"
#import "../Crypto/aes.h"

extern NSString *PDFMD5FinishedException;



@interface PDFMD5Engine:NSObject
{
	MD5_CTX md5;
	unsigned char digest_bytes[16];
	BOOL done;
}

+(PDFMD5Engine *)engine;
+(NSData *)digestForData:(NSData *)data;
+(NSData *)digestForBytes:(const void *)bytes length:(int)length;

-(id)init;

-(void)updateWithData:(NSData *)data;
-(void)updateWithBytes:(const void *)bytes length:(unsigned long)length;

-(NSData *)digest;
-(NSString *)hexDigest;

-(NSString *)description;

@end




@interface PDFAESHandle:CSBlockStreamHandle
{
	CSHandle *parent;
	off_t startoffs;

	NSData *key,*iv;

	aes_decrypt_ctx aes;
	uint8_t ivbuffer[16],streambuffer[16];
}

-(id)initWithHandle:(CSHandle *)handle key:(NSData *)keydata;
-(void)dealloc;

-(void)resetBlockStream;
-(int)produceBlockAtOffset:(off_t)pos;

@end

