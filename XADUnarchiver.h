/*
 * XADUnarchiver.h
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

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wquoted-include-in-framework-header"
#import "XADTypes.h"
#import "XADArchiveParser.h"
#pragma clang diagnostic pop

typedef NS_ENUM(int, XADForkStyle) {
	XADForkStyleIgnored = 0,
	XADForkStyleMacOSX = 1,
	XADForkStyleHiddenAppleDouble = 2,
	XADForkStyleVisibleAppleDouble = 3,
	XADForkStyleHFVExplorerAppleDouble = 4,
	
#if defined(__APPLE__) && TARGET_OS_OSX
	XADForkStyleDefault = XADForkStyleMacOSX,
#else
	XADForkStyleDefault = XADForkStyleVisibleAppleDouble,
#endif
};

@protocol XADUnarchiverDelegate;

XADEXPORT
@interface XADUnarchiver:NSObject <XADArchiveParserDelegate>
{
	XADArchiveParser *parser;
	NSString *destination;
	XADForkStyle forkstyle;
	BOOL preservepermissions;
	double updateinterval;

	id<XADUnarchiverDelegate> delegate;
	BOOL shouldstop;

	NSMutableArray *deferreddirectories,*deferredlinks;
}

+(XADUnarchiver *)unarchiverForArchiveParser:(XADArchiveParser *)archiveparser;
+(XADUnarchiver *)unarchiverForPath:(NSString *)path;
+(XADUnarchiver *)unarchiverForPath:(NSString *)path error:(XADError *)errorptr;
+(XADUnarchiver *)unarchiverForPath:(NSString *)path nserror:(NSError **)errorptr;

-(id)initWithArchiveParser:(XADArchiveParser *)archiveparser;
-(void)dealloc;

@property (readonly, retain) XADArchiveParser *archiveParser;

@property (assign) id<XADUnarchiverDelegate> delegate;

@property (copy) NSString *destination;

@property XADForkStyle macResourceForkStyle;

@property BOOL preservesPermissions;
-(void)setPreserevesPermissions:(BOOL)preserveflag API_DEPRECATED_WITH_REPLACEMENT("-setPreservesPermissions:", macosx(10.0, 10.8), ios(3.0, 8.0));

@property NSTimeInterval updateInterval;

-(XADError)parseAndUnarchive NS_REFINED_FOR_SWIFT;
-(BOOL)parseAndUnarchiveWithError:(NSError**)outErr NS_SWIFT_NAME(parseAndUnarchive());

-(XADError)extractEntryWithDictionary:(NSDictionary *)dict;
-(XADError)extractEntryWithDictionary:(NSDictionary *)dict forceDirectories:(BOOL)force;
-(XADError)extractEntryWithDictionary:(NSDictionary *)dict as:(NSString *)path;
-(XADError)extractEntryWithDictionary:(NSDictionary *)dict as:(NSString *)path forceDirectories:(BOOL)force;
-(BOOL)extractEntryWithDictionary:(NSDictionary *)dict as:(NSString *)path forceDirectories:(BOOL)force error:(NSError **)outErr;

-(XADError)finishExtractions;
-(XADError)_fixDeferredLinks;
-(XADError)_fixDeferredDirectories;

-(XADUnarchiver *)unarchiverForEntryWithDictionary:(NSDictionary *)dict
wantChecksum:(BOOL)checksum error:(XADError *)errorptr;
-(XADUnarchiver *)unarchiverForEntryWithDictionary:(NSDictionary *)dict
resourceForkDictionary:(NSDictionary *)forkdict wantChecksum:(BOOL)checksum error:(XADError *)errorptr;
-(XADUnarchiver *)unarchiverForEntryWithDictionary:(NSDictionary *)dict
wantChecksum:(BOOL)checksum nserror:(NSError **)errorptr;
-(XADUnarchiver *)unarchiverForEntryWithDictionary:(NSDictionary *)dict
resourceForkDictionary:(NSDictionary *)forkdict wantChecksum:(BOOL)checksum
nserror:(NSError **)errorptr;

-(XADError)_extractFileEntryWithDictionary:(NSDictionary *)dict as:(NSString *)destpath;
-(XADError)_extractDirectoryEntryWithDictionary:(NSDictionary *)dict as:(NSString *)destpath;
-(XADError)_extractLinkEntryWithDictionary:(NSDictionary *)dict as:(NSString *)destpath;
-(XADError)_extractArchiveEntryWithDictionary:(NSDictionary *)dict to:(NSString *)destpath name:(NSString *)filename;
-(XADError)_extractResourceForkEntryWithDictionary:(NSDictionary *)dict asAppleDoubleFile:(NSString *)destpath;

-(XADError)_updateFileAttributesAtPath:(NSString *)path forEntryWithDictionary:(NSDictionary *)dict
deferDirectories:(BOOL)defer;
-(XADError)_ensureDirectoryExists:(NSString *)path;
-(BOOL)_ensureDirectoryExists:(NSString *)path error:(NSError**)outError;

-(XADError)runExtractorWithDictionary:(NSDictionary *)dict outputHandle:(CSHandle *)handle;
-(XADError)runExtractorWithDictionary:(NSDictionary *)dict
outputTarget:(id)target selector:(SEL)sel argument:(id)arg;
-(BOOL)runExtractorWithDictionary:(NSDictionary *)dict
outputHandle:(CSHandle *)handle error:(NSError**)outError;
-(BOOL)runExtractorWithDictionary:(NSDictionary *)dict
outputTarget:(id)target selector:(SEL)sel argument:(id)arg error:(NSError**)outError;

-(NSString *)adjustPathString:(NSString *)path forEntryWithDictionary:(NSDictionary *)dict;

-(BOOL)_shouldStop;

@end




@protocol XADUnarchiverDelegate <NSObject>

@optional
-(void)unarchiverNeedsPassword:(XADUnarchiver *)unarchiver;

-(BOOL)unarchiver:(XADUnarchiver *)unarchiver shouldExtractEntryWithDictionary:(NSDictionary *)dict suggestedPath:(NSString **)pathptr;
-(void)unarchiver:(XADUnarchiver *)unarchiver willExtractEntryWithDictionary:(NSDictionary *)dict to:(NSString *)path;
-(void)unarchiver:(XADUnarchiver *)unarchiver didExtractEntryWithDictionary:(NSDictionary *)dict to:(NSString *)path error:(XADError)error;
-(void)unarchiver:(XADUnarchiver *)unarchiver didExtractEntryWithDictionary:(NSDictionary *)dict to:(NSString *)path nserror:(NSError*)error;

@required
-(BOOL)unarchiver:(XADUnarchiver *)unarchiver shouldCreateDirectory:(NSString *)directory;
@optional
-(void)unarchiver:(XADUnarchiver *)unarchiver didCreateDirectory:(NSString *)directory;
-(BOOL)unarchiver:(XADUnarchiver *)unarchiver shouldDeleteFileAndCreateDirectory:(NSString *)directory;

@optional
-(BOOL)unarchiver:(XADUnarchiver *)unarchiver shouldExtractArchiveEntryWithDictionary:(NSDictionary *)dict to:(NSString *)path;
-(void)unarchiver:(XADUnarchiver *)unarchiver willExtractArchiveEntryWithDictionary:(NSDictionary *)dict withUnarchiver:(XADUnarchiver *)subunarchiver to:(NSString *)path;
-(void)unarchiver:(XADUnarchiver *)unarchiver didExtractArchiveEntryWithDictionary:(NSDictionary *)dict withUnarchiver:(XADUnarchiver *)subunarchiver to:(NSString *)path error:(XADError)error;
-(void)unarchiver:(XADUnarchiver *)unarchiver didExtractArchiveEntryWithDictionary:(NSDictionary *)dict withUnarchiver:(XADUnarchiver *)subunarchiver to:(NSString *)path nserror:(NSError*)error;

@required
-(NSString *)unarchiver:(XADUnarchiver *)unarchiver destinationForLink:(XADString *)link from:(NSString *)path;

-(BOOL)extractionShouldStopForUnarchiver:(XADUnarchiver *)unarchiver;
-(void)unarchiver:(XADUnarchiver *)unarchiver extractionProgressForEntryWithDictionary:(NSDictionary *)dict
fileFraction:(double)fileprogress estimatedTotalFraction:(double)totalprogress;

@optional
-(void)unarchiver:(XADUnarchiver *)unarchiver findsFileInterestingForReason:(NSString *)reason;

@optional
// Deprecated.
-(NSString *)unarchiver:(XADUnarchiver *)unarchiver pathForExtractingEntryWithDictionary:(NSDictionary *)dict DEPRECATED_ATTRIBUTE;
-(BOOL)unarchiver:(XADUnarchiver *)unarchiver shouldExtractEntryWithDictionary:(NSDictionary *)dict to:(NSString *)path DEPRECATED_ATTRIBUTE;
-(NSString *)unarchiver:(XADUnarchiver *)unarchiver linkDestinationForEntryWithDictionary:(NSDictionary *)dict from:(NSString *)path DEPRECATED_ATTRIBUTE;
@end


static const XADForkStyle XADIgnoredForkStyle API_DEPRECATED_WITH_REPLACEMENT("XADForkStyleIgnored", macosx(10.0, 10.8), ios(3.0, 8.0)) = XADForkStyleIgnored;
static const XADForkStyle XADMacOSXForkStyle API_DEPRECATED_WITH_REPLACEMENT("XADForkStyleMacOSX", macosx(10.0, 10.8), ios(3.0, 8.0)) = XADForkStyleMacOSX;
static const XADForkStyle XADHiddenAppleDoubleForkStyle API_DEPRECATED_WITH_REPLACEMENT("XADForkStyleHiddenAppleDouble", macosx(10.0, 10.8), ios(3.0, 8.0)) = XADForkStyleHiddenAppleDouble;
static const XADForkStyle XADVisibleAppleDoubleForkStyle API_DEPRECATED_WITH_REPLACEMENT("XADForkStyleVisibleAppleDouble", macosx(10.0, 10.8), ios(3.0, 8.0)) = XADForkStyleVisibleAppleDouble;
static const XADForkStyle XADHFVExplorerAppleDoubleForkStyle API_DEPRECATED_WITH_REPLACEMENT("XADForkStyleHFVExplorerAppleDouble", macosx(10.0, 10.8), ios(3.0, 8.0)) = XADForkStyleHFVExplorerAppleDouble;
static const XADForkStyle XADDefaultForkStyle API_DEPRECATED_WITH_REPLACEMENT("XADForkStyleDefault", macosx(10.0, 10.8), ios(3.0, 8.0)) = XADForkStyleDefault;
