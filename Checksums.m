/*
 * Checksums.m
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
#import "Checksums.h"




@implementation CSHandle (Checksums)

-(BOOL)hasChecksum { return NO; }
-(BOOL)isChecksumCorrect { return YES; }

@end




@implementation CSSubHandle (Checksums)

-(BOOL)hasChecksum
{
	off_t length=[parent fileSize];
	if(length==CSHandleMaxLength) return NO;

	return end==length&&[parent hasChecksum];
}

-(BOOL)isChecksumCorrect { return [parent isChecksumCorrect]; }

@end




@implementation CSStreamHandle (Checksums)

-(BOOL)hasChecksum
{
	if(input) return [CSInputHandle(input) hasChecksum];
	else return NO;
}

-(BOOL)isChecksumCorrect
{
	if(input) return [CSInputHandle(input) isChecksumCorrect];
	else return YES;
}

@end




@implementation CSChecksumWrapperHandle

-(id)initWithHandle:(CSHandle *)handle checksumHandle:(CSHandle *)checksumhandle
{
	if((self=[super initWithParentHandle:handle]))
	{
		checksum=[checksumhandle retain];
	}
	return self;
}

-(void)dealloc
{
	[checksum release];
	[super dealloc];
}

-(off_t)fileSize { return [parent fileSize]; }
-(off_t)offsetInFile { return [parent offsetInFile]; }
-(BOOL)atEndOfFile { return [parent atEndOfFile]; }
-(void)seekToFileOffset:(off_t)offs { [parent seekToFileOffset:offs]; }
-(void)seekToEndOfFile { [parent seekToEndOfFile]; }
-(void)pushBackByte:(int)byte { [parent pushBackByte:byte]; }
-(int)readAtMost:(int)num toBuffer:(void *)buffer { return [parent readAtMost:num toBuffer:buffer]; }
-(void)writeBytes:(int)num fromBuffer:(const void *)buffer { [parent writeBytes:num fromBuffer:buffer]; }

-(BOOL)hasChecksum { return [checksum hasChecksum]; }
-(BOOL)isChecksumCorrect { return [checksum isChecksumCorrect]; }

@end
