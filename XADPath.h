/*
 * XADPath.h
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
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wquoted-include-in-framework-header"
#import "XADString.h"
#pragma clang diagnostic pop

#define XADUnixPathSeparator "/"
#define XADWindowsPathSeparator "\\"
#define XADEitherPathSeparator "/\\"
#define XADNoPathSeparator ""

XADEXPORT
@interface XADPath:NSObject <XADString,NSCopying>
{
	XADPath *parent;

	NSArray *cachedcanonicalcomponents;
	NSString *cachedencoding;
}

+(XADPath *)emptyPath;
+(XADPath *)pathWithString:(NSString *)string;
+(XADPath *)pathWithStringComponents:(NSArray *)components;
+(XADPath *)separatedPathWithString:(NSString *)string;
+(XADPath *)decodedPathWithData:(NSData *)bytedata encodingName:(XADStringEncodingName)encoding separators:(const char *)separators;
+(XADPath *)analyzedPathWithData:(NSData *)bytedata source:(XADStringSource *)stringsource
separators:(const char *)pathseparators;

-(id)init;
-(id)initWithParent:(XADPath *)parentpath;
-(id)initWithPath:(XADPath *)path parent:(XADPath *)parentpath;

-(void)dealloc;

-(BOOL)isAbsolute;
-(BOOL)isEmpty;
-(BOOL)isEqual:(id)other;
-(BOOL)isCanonicallyEqual:(id)other;
-(BOOL)isCanonicallyEqual:(id)other encodingName:(XADStringEncodingName)encoding;
-(BOOL)hasPrefix:(XADPath *)other;
-(BOOL)hasCanonicalPrefix:(XADPath *)other;
-(BOOL)hasCanonicalPrefix:(XADPath *)other encodingName:(XADStringEncodingName)encoding;

-(int)depth; // Note: Does not take . or .. paths into account.
-(int)depthWithEncodingName:(XADStringEncodingName)encoding;
-(NSArray *)pathComponents;
-(NSArray *)pathComponentsWithEncodingName:(XADStringEncodingName)encoding;
-(NSArray *)canonicalPathComponents;
-(NSArray *)canonicalPathComponentsWithEncodingName:(XADStringEncodingName)encoding;
-(void)_addPathComponentsToArray:(NSMutableArray *)components encodingName:(XADStringEncodingName)encoding;

-(NSString *)lastPathComponent;
-(NSString *)lastPathComponentWithEncodingName:(XADStringEncodingName)encoding;
-(NSString *)firstPathComponent;
-(NSString *)firstPathComponentWithEncodingName:(XADStringEncodingName)encoding;
-(NSString *)firstCanonicalPathComponent;
-(NSString *)firstCanonicalPathComponentWithEncodingName:(XADStringEncodingName)encoding;

-(XADPath *)pathByDeletingLastPathComponent;
-(XADPath *)pathByDeletingLastPathComponentWithEncodingName:(XADStringEncodingName)encoding;
-(XADPath *)pathByDeletingFirstPathComponent;
-(XADPath *)pathByDeletingFirstPathComponentWithEncodingName:(XADStringEncodingName)encoding;

-(XADPath *)pathByAppendingXADStringComponent:(XADString *)component;
-(XADPath *)pathByAppendingPath:(XADPath *)path;
-(XADPath *)_copyWithParent:(XADPath *)newparent;

// These are safe for filesystem use, and adapted to the current platform.
-(NSString *)sanitizedPathString;
-(NSString *)sanitizedPathStringWithEncodingName:(XADStringEncodingName)encoding;

// XADString interface.
// NOTE: These are not guaranteed to be safe for usage as filesystem paths,
// only for display!
-(BOOL)canDecodeWithEncodingName:(XADStringEncodingName)encoding;
-(NSString *)string;
-(NSString *)stringWithEncodingName:(XADStringEncodingName)encoding;
-(NSData *)data;
-(void)_appendPathToData:(NSMutableData *)data;

@property (readonly, nonatomic) BOOL encodingIsKnown;
@property (readonly, copy) XADStringEncodingName encodingName;
@property (readonly) float confidence;

-(XADStringSource *)source;

#ifdef __APPLE__
-(BOOL)canDecodeWithEncoding:(NSStringEncoding)encoding;
-(NSString *)stringWithEncoding:(NSStringEncoding)encoding;
-(NSString *)sanitizedPathStringWithEncoding:(NSStringEncoding)encoding;
-(NSStringEncoding)encoding;
#endif

// Deprecated.
-(XADPath *)safePath DEPRECATED_ATTRIBUTE; // Deprecated. Use sanitizedPathString: instead.

// Subclass methods.
-(BOOL)_isPartAbsolute;
-(BOOL)_isPartEmpty;
-(int)_depthOfPartWithEncodingName:(XADStringEncodingName)encoding;
-(void)_addPathComponentsOfPartToArray:(NSMutableArray *)array encodingName:(XADStringEncodingName)encoding;
-(NSString *)_lastPathComponentOfPartWithEncodingName:(XADStringEncodingName)encoding;
-(NSString *)_firstPathComponentOfPartWithEncodingName:(XADStringEncodingName)encoding;
-(XADPath *)_pathByDeletingLastPathComponentOfPartWithEncodingName:(XADStringEncodingName)encoding;
-(XADPath *)_pathByDeletingFirstPathComponentOfPartWithEncodingName:(XADStringEncodingName)encoding;
-(BOOL)_canDecodePartWithEncodingName:(XADStringEncodingName)encoding;
-(void)_appendPathForPartToData:(NSMutableData *)data;
-(XADStringSource *)_sourceForPart;

@end


XADEXPORT
@interface XADStringPath:XADPath
{
	NSString *string;
}

-(id)initWithComponentString:(NSString *)pathstring;
-(id)initWithComponentString:(NSString *)pathstring parent:(XADPath *)parentpath;
-(id)initWithPath:(XADStringPath *)path parent:(XADPath *)parentpath;
-(void)dealloc;

-(BOOL)_isPartAbsolute;
-(BOOL)_isPartEmpty;
-(int)_depthOfPartWithEncodingName:(XADStringEncodingName)encoding;
-(void)_addPathComponentsOfPartToArray:(NSMutableArray *)array encodingName:(XADStringEncodingName)encoding;
-(NSString *)_lastPathComponentOfPartWithEncodingName:(XADStringEncodingName)encoding;
-(NSString *)_firstPathComponentOfPartWithEncodingName:(XADStringEncodingName)encoding;
-(XADPath *)_pathByDeletingLastPathComponentOfPartWithEncodingName:(XADStringEncodingName)encoding;
-(XADPath *)_pathByDeletingFirstPathComponentOfPartWithEncodingName:(XADStringEncodingName)encoding;
-(BOOL)_canDecodePartWithEncodingName:(XADStringEncodingName)encoding;
-(void)_appendPathForPartToData:(NSMutableData *)data;
-(XADStringSource *)_sourceForPart;

-(BOOL)isEqual:(id)other;
-(NSUInteger)hash;

@end

XADEXPORT
@interface XADRawPath:XADPath
{
	NSData *data;
	XADStringSource *source;
	const char *separators;
}

-(id)initWithData:(NSData *)bytedata source:(XADStringSource *)stringsource
separators:(const char *)pathseparators;
-(id)initWithData:(NSData *)bytedata source:(XADStringSource *)stringsource
separators:(const char *)pathseparators parent:(XADPath *)parentpath;
-(id)initWithPath:(XADRawPath *)path parent:(XADPath *)parentpath;
-(void)dealloc;

-(BOOL)_isPartAbsolute;
-(BOOL)_isPartEmpty;
-(int)_depthOfPartWithEncodingName:(XADStringEncodingName)encoding;
-(void)_addPathComponentsOfPartToArray:(NSMutableArray *)array encodingName:(XADStringEncodingName)encoding;
-(NSString *)_lastPathComponentOfPartWithEncodingName:(XADStringEncodingName)encoding;
-(NSString *)_firstPathComponentOfPartWithEncodingName:(XADStringEncodingName)encoding;
-(XADPath *)_pathByDeletingLastPathComponentOfPartWithEncodingName:(XADStringEncodingName)encoding;
-(XADPath *)_pathByDeletingFirstPathComponentOfPartWithEncodingName:(XADStringEncodingName)encoding;
-(BOOL)_canDecodePartWithEncodingName:(XADStringEncodingName)encoding;
-(void)_appendPathForPartToData:(NSMutableData *)data;
-(XADStringSource *)_sourceForPart;

@end

