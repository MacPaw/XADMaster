/*
 * CSFileHandle.h
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
#import "CSHandle.h"

#import <stdio.h>

#define CSFileHandle XADFileHandle

extern NSExceptionName const CSCannotOpenFileException;
extern NSExceptionName const CSFileErrorException;

@interface CSFileHandle:CSHandle
{
	FILE *fh;
	NSString *path;
	BOOL close;

	NSLock *multilock;
	CSFileHandle *fhowner;
	off_t pos;
}

+(CSFileHandle *)fileHandleForReadingAtPath:(NSString *)path;
+(CSFileHandle *)fileHandleForWritingAtPath:(NSString *)path;
+(CSFileHandle *)fileHandleForPath:(NSString *)path modes:(NSString *)modes;
+(CSFileHandle *)fileHandleForReadingAtFileURL:(NSURL *)path NS_SWIFT_UNAVAILABLE("Use throwing methods instead");
+(CSFileHandle *)fileHandleForWritingAtFileURL:(NSURL *)path NS_SWIFT_UNAVAILABLE("Use throwing methods instead");
+(CSFileHandle *)fileHandleForFileURL:(NSURL *)path modes:(NSString *)modes NS_SWIFT_UNAVAILABLE("Use throwing methods instead");
+(CSFileHandle *)fileHandleForReadingAtFileURL:(NSURL *)path error:(NSError**)outErr;
+(CSFileHandle *)fileHandleForWritingAtFileURL:(NSURL *)path error:(NSError**)outErr;
+(CSFileHandle *)fileHandleForFileURL:(NSURL *)path modes:(NSString *)modes error:(NSError**)outErr;
+(CSFileHandle *)fileHandleForStandardInput;
+(CSFileHandle *)fileHandleForStandardOutput;
+(CSFileHandle *)fileHandleForStandardError;

// Initializers
-(id)initWithFilePointer:(FILE *)file closeOnDealloc:(BOOL)closeondealloc path:(NSString *)filepath;
-(id)initAsCopyOf:(CSFileHandle *)other;
-(void)dealloc;
-(void)close;

// Public methods
@property (readonly) FILE *filePointer NS_RETURNS_INNER_POINTER;

// Implemented by this class
@property (readonly) off_t fileSize;
@property (readonly) off_t offsetInFile;
@property (readonly) BOOL atEndOfFile;

-(void)seekToFileOffset:(off_t)offs;
-(void)seekToEndOfFile;
-(void)pushBackByte:(int)byte;
-(int)readAtMost:(int)num toBuffer:(void *)buffer;
-(void)writeBytes:(int)num fromBuffer:(const void *)buffer;

-(NSString *)name;

// Internal methods
-(void)_raiseError;
-(void)_setMultiMode;

@end
