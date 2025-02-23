/*
 * XADArchive.h
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
#import "XADArchiveParser.h"
#import "XADUnarchiver.h"
#import "XADException.h"
#pragma clang diagnostic pop

#if __has_feature(modules)
#  define XAD_NO_DEPRECATED
#endif

typedef NS_ENUM(int, XADAction) {
	XADActionAbort = 0,
	XADActionRetry = 1,
	XADActionSkip = 2,
	XADActionOverwrite = 3,
	XADActionRename = 4
};
//typedef off_t xadSize; // deprecated

XADEXTERN NSString *const XADResourceDataKey;
XADEXTERN NSString *const XADFinderFlags;


@class UniversalDetector;
@class XADArchive;
@protocol XADArchiveDelegate <NSObject>
@optional

-(NSStringEncoding)archive:(XADArchive *)archive encodingForData:(NSData *)data guess:(NSStringEncoding)guess confidence:(float)confidence;
-(XADAction)archive:(XADArchive *)archive nameDecodingDidFailForEntry:(NSInteger)n data:(NSData *)data;

-(BOOL)archiveExtractionShouldStop:(XADArchive *)archive;
-(BOOL)archive:(XADArchive *)archive shouldCreateDirectory:(NSString *)directory;
-(void)archive:(XADArchive *)archive didCreateDirectory:(NSString *)directory;
-(XADAction)archive:(XADArchive *)archive entry:(NSInteger)n collidesWithFile:(NSString *)file newFilename:(NSString **)newname;
-(XADAction)archive:(XADArchive *)archive entry:(NSInteger)n collidesWithDirectory:(NSString *)file newFilename:(NSString **)newname;
-(XADAction)archive:(XADArchive *)archive creatingDirectoryDidFailForEntry:(NSInteger)n;

-(void)archiveNeedsPassword:(XADArchive *)archive;

-(void)archive:(XADArchive *)archive extractionOfEntryWillStart:(NSInteger)n;
-(void)archive:(XADArchive *)archive extractionProgressForEntry:(NSInteger)n bytes:(off_t)bytes of:(off_t)total;
-(void)archive:(XADArchive *)archive extractionOfEntryDidSucceed:(NSInteger)n;
-(XADAction)archive:(XADArchive *)archive extractionOfEntryDidFail:(NSInteger)n error:(XADError)error;
-(XADAction)archive:(XADArchive *)archive extractionOfResourceForkForEntryDidFail:(NSInteger)n error:(XADError)error;

-(void)archive:(XADArchive *)archive extractionProgressBytes:(off_t)bytes of:(off_t)total;

@optional
-(void)archive:(XADArchive *)archive extractionProgressFiles:(NSInteger)files of:(NSInteger)total;

@optional
// Deprecated
-(NSStringEncoding)archive:(XADArchive *)archive encodingForName:(const char *)bytes guess:(NSStringEncoding)guess confidence:(float)confidence DEPRECATED_ATTRIBUTE;
-(XADAction)archive:(XADArchive *)archive nameDecodingDidFailForEntry:(NSInteger)n bytes:(const char *)bytes DEPRECATED_ATTRIBUTE;

@end

XADEXPORT
@interface XADArchive:NSObject <XADArchiveDelegate, XADUnarchiverDelegate, XADArchiveParserDelegate>
{
	XADArchiveParser *parser;
	XADUnarchiver *unarchiver;

	id<XADArchiveDelegate> delegate;
	NSTimeInterval update_interval;
	XADError lasterror;

	NSMutableArray *dataentries,*resourceentries;
	NSMutableDictionary *namedict;

	off_t extractsize,totalsize;
	int extractingentry;
	BOOL extractingresource;
	NSString *immediatedestination;
	BOOL immediatesubarchives,immediatefailed;
	off_t immediatesize;
	XADArchive *parentarchive;
}

+(XADArchive *)archiveForFile:(NSString *)filename;
+(XADArchive *)recursiveArchiveForFile:(NSString *)filename;



-(id)init;
-(id)initWithFile:(NSString *)file;
-(id)initWithFile:(NSString *)file error:(XADError *)error;
-(id)initWithFile:(NSString *)file delegate:(id<XADArchiveDelegate>)del error:(XADError *)error;
-(id)initWithData:(NSData *)data;
-(id)initWithData:(NSData *)data error:(XADError *)error;
-(id)initWithData:(NSData *)data delegate:(id<XADArchiveDelegate>)del error:(XADError *)error;
-(id)initWithArchive:(XADArchive *)archive entry:(NSInteger)n;
-(id)initWithArchive:(XADArchive *)archive entry:(NSInteger)n error:(XADError *)error;
-(id)initWithArchive:(XADArchive *)otherarchive entry:(NSInteger)n delegate:(id<XADArchiveDelegate>)del error:(XADError *)error;
-(id)initWithArchive:(XADArchive *)otherarchive entry:(NSInteger)n
     immediateExtractionTo:(NSString *)destination error:(XADError *)error;
-(id)initWithArchive:(XADArchive *)otherarchive entry:(NSInteger)n
     immediateExtractionTo:(NSString *)destination subArchives:(BOOL)sub error:(XADError *)error;
-(void)dealloc;

-(id)initWithFile:(NSString *)file nserror:(NSError **)error;
-(id)initWithFile:(NSString *)file delegate:(id<XADArchiveDelegate>)del nserror:(NSError **)error;
-(id)initWithData:(NSData *)data nserror:(NSError **)error;
-(id)initWithData:(NSData *)data delegate:(id<XADArchiveDelegate>)del nserror:(NSError **)error;
-(id)initWithArchive:(XADArchive *)archive entry:(NSInteger)n nserror:(NSError **)error;
-(id)initWithArchive:(XADArchive *)otherarchive entry:(NSInteger)n delegate:(id<XADArchiveDelegate>)del nserror:(NSError **)error;
-(id)initWithArchive:(XADArchive *)otherarchive entry:(NSInteger)n
immediateExtractionTo:(NSString *)destination nserror:(NSError **)error;
-(id)initWithArchive:(XADArchive *)otherarchive entry:(NSInteger)n
immediateExtractionTo:(NSString *)destination subArchives:(BOOL)sub nserror:(NSError **)error;

-(id)initWithFileURL:(NSURL *)file delegate:(id<XADArchiveDelegate>)del error:(NSError **)error;

-(BOOL)_parseWithErrorPointer:(XADError *)error;

-(NSString *)filename;
-(NSArray *)allFilenames;
-(NSString *)formatName;
-(BOOL)isEncrypted;
-(BOOL)isSolid;
-(BOOL)isCorrupted;
-(NSInteger)numberOfEntries;
@property (readonly) BOOL immediateExtractionFailed;
-(NSString *)commonTopDirectory;
-(NSString *)comment;

@property (assign) id<XADArchiveDelegate> delegate;

-(NSString *)password;
-(void)setPassword:(NSString *)newpassword;

-(NSStringEncoding)nameEncoding;
-(void)setNameEncoding:(NSStringEncoding)encoding;

@property (readonly) XADError lastError;
-(void)clearLastError;
-(NSString *)describeLastError;
-(NSString *)describeError:(XADError)error;



-(NSDictionary *)dataForkParserDictionaryForEntry:(NSInteger)n;
-(NSDictionary *)resourceForkParserDictionaryForEntry:(NSInteger)n;
-(NSDictionary *)combinedParserDictionaryForEntry:(NSInteger)n;

-(NSString *)nameOfEntry:(NSInteger)n;
-(BOOL)entryHasSize:(NSInteger)n;
-(off_t)uncompressedSizeOfEntry:(NSInteger)n;
-(off_t)compressedSizeOfEntry:(NSInteger)n;
-(off_t)representativeSizeOfEntry:(NSInteger)n;
-(BOOL)entryIsDirectory:(NSInteger)n;
-(BOOL)entryIsLink:(NSInteger)n;
-(BOOL)entryIsEncrypted:(NSInteger)n;
-(BOOL)entryIsArchive:(NSInteger)n;
-(BOOL)entryHasResourceFork:(NSInteger)n;
-(NSString *)commentForEntry:(NSInteger)n;
-(NSDictionary *)attributesOfEntry:(NSInteger)n;
-(NSDictionary *)attributesOfEntry:(NSInteger)n withResourceFork:(BOOL)resfork;
-(CSHandle *)handleForEntry:(NSInteger)n;
-(CSHandle *)handleForEntry:(NSInteger)n error:(XADError *)error;
-(CSHandle *)resourceHandleForEntry:(NSInteger)n;
-(CSHandle *)resourceHandleForEntry:(NSInteger)n error:(XADError *)error;
-(NSData *)contentsOfEntry:(NSInteger)n;
//-(NSData *)resourceContentsOfEntry:(int)n;

-(BOOL)extractTo:(NSString *)destination;
-(BOOL)extractTo:(NSString *)destination subArchives:(BOOL)sub;
-(BOOL)extractEntries:(NSIndexSet *)entryset to:(NSString *)destination;
-(BOOL)extractEntries:(NSIndexSet *)entryset to:(NSString *)destination subArchives:(BOOL)sub;
-(BOOL)extractEntry:(NSInteger)n to:(NSString *)destination;
-(BOOL)extractEntry:(NSInteger)n to:(NSString *)destination deferDirectories:(BOOL)defer;
-(BOOL)extractEntry:(NSInteger)n to:(NSString *)destination deferDirectories:(BOOL)defer
resourceFork:(BOOL)resfork;
-(BOOL)extractEntry:(NSInteger)n to:(NSString *)destination deferDirectories:(BOOL)defer
dataFork:(BOOL)datafork resourceFork:(BOOL)resfork;
-(BOOL)extractArchiveEntry:(NSInteger)n to:(NSString *)destination;

-(BOOL)_extractEntry:(NSInteger)n as:(NSString *)destfile deferDirectories:(BOOL)defer
dataFork:(BOOL)datafork resourceFork:(BOOL)resfork;

-(void)updateAttributesForDeferredDirectories;

// Deprecated

+(NSArray *)volumesForFile:(NSString *)filename DEPRECATED_ATTRIBUTE;

-(int)sizeOfEntry:(int)n DEPRECATED_ATTRIBUTE;
-(void *)xadFileInfoForEntry:(int)n DEPRECATED_ATTRIBUTE;
-(BOOL)extractEntry:(int)n to:(NSString *)destination overrideWritePermissions:(BOOL)override DEPRECATED_ATTRIBUTE;
-(BOOL)extractEntry:(int)n to:(NSString *)destination overrideWritePermissions:(BOOL)override resourceFork:(BOOL)resfork DEPRECATED_ATTRIBUTE;
-(void)fixWritePermissions DEPRECATED_ATTRIBUTE;

@end


#ifndef XAD_NO_DEPRECATED

static const XADAction XADAbort API_DEPRECATED_WITH_REPLACEMENT("XADActionAbort", macosx(10.0, 10.8), ios(3.0, 8.0)) = XADActionAbort;
static const XADAction XADRetry API_DEPRECATED_WITH_REPLACEMENT("XADActionRetry", macosx(10.0, 10.8), ios(3.0, 8.0)) = XADActionRetry;
static const XADAction XADSkip API_DEPRECATED_WITH_REPLACEMENT("XADActionSkip", macosx(10.0, 10.8), ios(3.0, 8.0)) = XADActionSkip;
static const XADAction XADOverwrite API_DEPRECATED_WITH_REPLACEMENT("XADActionOverwrite", macosx(10.0, 10.8), ios(3.0, 8.0)) = XADActionOverwrite;
static const XADAction XADRename API_DEPRECATED_WITH_REPLACEMENT("XADActionRename", macosx(10.0, 10.8), ios(3.0, 8.0)) = XADActionRename;

typedef XADError xadERROR;
typedef off_t xadSize;

#define XADERR_NO XADNoError
#if 0
#define XADUnknownError          0x0001 /* unknown error */
#define XADInputError            0x0002 /* input data buffers border exceeded */
#define XADOutputError           0x0003 /* output data buffers border exceeded */
#define XADBadParametersError    0x0004 /* function called with illegal parameters */
#define XADOutOfMemoryError      0x0005 /* not enough memory available */
#define XADIllegalDataError      0x0006 /* data is corrupted */
#define XADNotSupportedError     0x0007 /* command is not supported */
#define XADResourceError         0x0008 /* required resource missing */
#define XADDecrunchError         0x0009 /* error on decrunching */
#define XADFiletypeError         0x000A /* unknown file type */
#define XADOpenFileError         0x000B /* opening file failed */
#define XADSkipError             0x000C /* file, disk has been skipped */
#define XADBreakError            0x000D /* user break in progress hook */
#define XADFileExistsError       0x000E /* file already exists */
#define XADPasswordError         0x000F /* missing or wrong password */
#define XADMakeDirectoryError    0x0010 /* could not create directory */
#define XADChecksumError         0x0011 /* wrong checksum */
#define XADVerifyError           0x0012 /* verify failed (disk hook) */
#define XADGeometryError         0x0013 /* wrong drive geometry */
#define XADDataFormatError       0x0014 /* unknown data format */
#define XADEmptyError            0x0015 /* source contains no files */
#define XADFileSystemError       0x0016 /* unknown filesystem */
#define XADFileDirectoryError    0x0017 /* name of file exists as directory */
#define XADShortBufferError      0x0018 /* buffer was too short */
#define XADEncodingError         0x0019 /* text encoding was defective */
#endif

#endif

static const XADAction XADAbortAction API_DEPRECATED_WITH_REPLACEMENT("XADActionAbort", macosx(10.0, 10.8), ios(3.0, 8.0)) = XADActionAbort;
static const XADAction XADRetryAction API_DEPRECATED_WITH_REPLACEMENT("XADActionRetry", macosx(10.0, 10.8), ios(3.0, 8.0)) = XADActionRetry;
static const XADAction XADSkipAction API_DEPRECATED_WITH_REPLACEMENT("XADActionSkip", macosx(10.0, 10.8), ios(3.0, 8.0)) = XADActionSkip;
static const XADAction XADOverwriteAction API_DEPRECATED_WITH_REPLACEMENT("XADActionOverwrite", macosx(10.0, 10.8), ios(3.0, 8.0)) = XADActionOverwrite;
static const XADAction XADRenameAction API_DEPRECATED_WITH_REPLACEMENT("XADActionRename", macosx(10.0, 10.8), ios(3.0, 8.0)) = XADActionRename;
