/*
 * PDFEncryptionUtils.m
 *
 * Copyright (c) 2017-present, MacPaw Inc. All rights reserved.
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
 * MA 02110-1301  USA
 */
#import "PDFEncryptionUtils.h"

NSString *PDFMD5FinishedException=@"PDFMD5FinishedException";



@implementation PDFMD5Engine

+(PDFMD5Engine *)engine { return [[[self class] new] autorelease]; }

+(NSData *)digestForData:(NSData *)data { return [self digestForBytes:[data bytes] length:[data length]]; }

+(NSData *)digestForBytes:(const void *)bytes length:(int)length
{
	PDFMD5Engine *md5=[[self class] new];
	[md5 updateWithBytes:bytes length:length];
	NSData *res=[md5 digest];
	[md5 release];
	return res;
}

-(id)init
{
	if(self=[super init])
	{
		MD5_Init(&md5);
		done=NO;
	}
	return self;
}

-(void)updateWithData:(NSData *)data { [self updateWithBytes:[data bytes] length:[data length]]; }

-(void)updateWithBytes:(const void *)bytes length:(unsigned long)length
{
	if(done) [NSException raise:PDFMD5FinishedException format:@"Attempted to update a finished %@ object",[self class]];
	MD5_Update(&md5,bytes,length);
}

-(NSData *)digest
{
	if(!done) { MD5_Final(digest_bytes,&md5); done=YES; }
	return [NSData dataWithBytes:digest_bytes length:16];
}

-(NSString *)hexDigest
{
	if(!done) { MD5_Final(digest_bytes,&md5); done=YES; }
	return [NSString stringWithFormat:@"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
	digest_bytes[0],digest_bytes[1],digest_bytes[2],digest_bytes[3],
	digest_bytes[4],digest_bytes[5],digest_bytes[6],digest_bytes[7],
	digest_bytes[8],digest_bytes[9],digest_bytes[10],digest_bytes[11],
	digest_bytes[12],digest_bytes[13],digest_bytes[14],digest_bytes[15]];
}

-(NSString *)description
{
	if(done) return [NSString stringWithFormat:@"<%@ with digest %@>",[self class],[self hexDigest]];
	else return [NSString stringWithFormat:@"<%@, unfinished>",[self class]];
}

@end




@implementation PDFAESHandle

-(id)initWithHandle:(CSHandle *)handle key:(NSData *)keydata
{
	if(self=[super initWithParentHandle:handle])
	{
		key=[keydata retain];

		iv=[parent copyDataOfLength:16];
		startoffs=[parent offsetInFile];

		[self setBlockPointer:streambuffer];

		aes_decrypt_key([key bytes],[key length]*8,&aes);
	}
	return self;
}

-(void)dealloc
{
	[key release];
	[iv release];
	[super dealloc];
}

-(void)resetBlockStream
{
	[parent seekToFileOffset:startoffs];
	memcpy(ivbuffer,[iv bytes],16);
}

-(int)produceBlockAtOffset:(off_t)pos
{
	uint8_t inbuf[16];
	[parent readBytes:16 toBuffer:inbuf];
	aes_cbc_decrypt(inbuf,streambuffer,16,ivbuffer,&aes);

	if([parent atEndOfFile])
	{
		[self endBlockStream];
		int val=streambuffer[15];
		if(val>0&&val<=16)
		{
			for(int i=1;i<val;i++) if(streambuffer[15-i]!=val) return 0;
			return 16-val;
		}
		else return 0;
	}
	else return 16;
}

@end

