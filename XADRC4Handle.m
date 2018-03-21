/*
 * XADRC4Handle.m
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
#import "XADRC4Handle.h"



@implementation XADRC4Handle

-(id)initWithHandle:(CSHandle *)handle key:(NSData *)keydata
{
	if(self=[super initWithParentHandle:handle length:[handle fileSize]])
	{
		startoffs=[parent offsetInFile];
		key=[keydata retain];
		rc4=nil;
	}
	return self;
}

-(void)dealloc
{
	[key release];
	[rc4 release];
	[super dealloc];
}

-(void)resetStream
{
	[parent seekToFileOffset:startoffs];
	[rc4 release];
	rc4=[(XADRC4Engine *)[XADRC4Engine alloc] initWithKey:key];
}

-(int)streamAtMost:(int)num toBuffer:(void *)buffer
{
	int actual=[parent readAtMost:num toBuffer:buffer];
	[rc4 encryptBytes:buffer length:actual];
	return actual;
}

@end





@implementation XADRC4Engine

+(XADRC4Engine *)engineWithKey:(NSData *)key
{
	return [[(XADRC4Engine *)[[self class] alloc] initWithKey:key] autorelease];
}

-(id)initWithKey:(NSData *)key
{
	if((self=[super init]))
	{
		const uint8_t *keybytes=[key bytes];
		int keylength=[key length];

		for(i=0;i<256;i++) s[i]=i;

		j=0;
		for(i=0;i<256;i++)
		{
			j=(j+s[i]+keybytes[i%keylength])&255;
			int tmp=s[i]; s[i]=s[j]; s[j]=tmp;
		}

		i=j=0;
	}
	return self;
}

-(NSData *)encryptedData:(NSData *)data
{
	NSMutableData *res=[NSMutableData dataWithData:data];
	[self encryptBytes:[res mutableBytes] length:[res length]];
	return [NSData dataWithData:res];
}

-(void)encryptBytes:(unsigned char *)bytes length:(int)length
{
	for(int n=0;n<length;n++)
	{
		i=(i+1)&255;
		j=(j+s[i])&255;
		int tmp=s[i]; s[i]=s[j]; s[j]=tmp;
		bytes[n]^=s[(s[i]+s[j])&255];
	}
}

-(void)skipBytes:(int)length
{
	for(int n=0;n<length;n++)
	{
		i=(i+1)&255;
		j=(j+s[i])&255;
		int tmp=s[i]; s[i]=s[j]; s[j]=tmp;
	}
}

@end

