/*
 * PDFEncryptionUtils.h
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

