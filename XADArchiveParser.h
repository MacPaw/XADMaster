/*
 * XADArchiveParser.h
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
#import "XADException.h"
#import "XADString.h"
#import "XADPath.h"
#import "XADRegex.h"
#import "CSHandle.h"
#import "XADSkipHandle.h"
#import "XADResourceFork.h"
#import "Checksums.h"
#pragma clang diagnostic pop

typedef NSString *XADArchiveKeys NS_TYPED_EXTENSIBLE_ENUM NS_SWIFT_NAME(XADArchiveParser.Keys);

XADEXTERN XADArchiveKeys const XADFileNameKey NS_SWIFT_NAME(fileName);
XADEXTERN XADArchiveKeys const XADCommentKey NS_SWIFT_NAME(comment);
XADEXTERN XADArchiveKeys const XADFileSizeKey NS_SWIFT_NAME(fileSize);
XADEXTERN XADArchiveKeys const XADCompressedSizeKey NS_SWIFT_NAME(compressedSize);
XADEXTERN XADArchiveKeys const XADCompressionNameKey NS_SWIFT_NAME(compressionName);

XADEXTERN XADArchiveKeys const XADLastModificationDateKey NS_SWIFT_NAME(lastModificationDate);
XADEXTERN XADArchiveKeys const XADLastAccessDateKey NS_SWIFT_NAME(lastAccessDate);
XADEXTERN XADArchiveKeys const XADLastAttributeChangeDateKey NS_SWIFT_NAME(lastAttributeChangeDate);
XADEXTERN XADArchiveKeys const XADLastBackupDateKey NS_SWIFT_NAME(lastBackupDate);
XADEXTERN XADArchiveKeys const XADCreationDateKey NS_SWIFT_NAME(creationDate);

XADEXTERN XADArchiveKeys const XADIsDirectoryKey NS_SWIFT_NAME(isDirectory);
XADEXTERN XADArchiveKeys const XADIsResourceForkKey NS_SWIFT_NAME(isResourceFork);
XADEXTERN XADArchiveKeys const XADIsArchiveKey NS_SWIFT_NAME(isArchive);
XADEXTERN XADArchiveKeys const XADIsHiddenKey NS_SWIFT_NAME(isHidden);
XADEXTERN XADArchiveKeys const XADIsLinkKey NS_SWIFT_NAME(isLink);
XADEXTERN XADArchiveKeys const XADIsHardLinkKey NS_SWIFT_NAME(isHardLink);
XADEXTERN XADArchiveKeys const XADLinkDestinationKey NS_SWIFT_NAME(linkDestination);
XADEXTERN XADArchiveKeys const XADIsCharacterDeviceKey NS_SWIFT_NAME(isCharacterDevice);
XADEXTERN XADArchiveKeys const XADIsBlockDeviceKey NS_SWIFT_NAME(isBlockDevice);
XADEXTERN XADArchiveKeys const XADDeviceMajorKey NS_SWIFT_NAME(deviceMajor);
XADEXTERN XADArchiveKeys const XADDeviceMinorKey NS_SWIFT_NAME(deviceMinor);
XADEXTERN XADArchiveKeys const XADIsFIFOKey NS_SWIFT_NAME(isFIFO);
XADEXTERN XADArchiveKeys const XADIsEncryptedKey NS_SWIFT_NAME(isEncrypted);
XADEXTERN XADArchiveKeys const XADIsCorruptedKey NS_SWIFT_NAME(isCorrupted);

XADEXTERN XADArchiveKeys const XADExtendedAttributesKey NS_SWIFT_NAME(extendedAttributes);
XADEXTERN XADArchiveKeys const XADFileTypeKey NS_SWIFT_NAME(fileType);
XADEXTERN XADArchiveKeys const XADFileCreatorKey NS_SWIFT_NAME(fileCreator);
XADEXTERN XADArchiveKeys const XADFinderFlagsKey NS_SWIFT_NAME(finderFlags);
XADEXTERN XADArchiveKeys const XADFinderInfoKey NS_SWIFT_NAME(finderInfo);
XADEXTERN XADArchiveKeys const XADPosixPermissionsKey NS_SWIFT_NAME(posixPermissions);
XADEXTERN XADArchiveKeys const XADPosixUserKey NS_SWIFT_NAME(posixUser);
XADEXTERN XADArchiveKeys const XADPosixGroupKey NS_SWIFT_NAME(posixGroup);
XADEXTERN XADArchiveKeys const XADPosixUserNameKey NS_SWIFT_NAME(posixUserName);
XADEXTERN XADArchiveKeys const XADPosixGroupNameKey NS_SWIFT_NAME(posixGroupName);
XADEXTERN XADArchiveKeys const XADDOSFileAttributesKey NS_SWIFT_NAME(dosFileAttributes);
XADEXTERN XADArchiveKeys const XADWindowsFileAttributesKey NS_SWIFT_NAME(windowsFileAttributes);
XADEXTERN XADArchiveKeys const XADAmigaProtectionBitsKey NS_SWIFT_NAME(amigaProtectionBits);

XADEXTERN XADArchiveKeys const XADIndexKey NS_SWIFT_NAME(index);
XADEXTERN XADArchiveKeys const XADDataOffsetKey NS_SWIFT_NAME(dataOffset);
XADEXTERN XADArchiveKeys const XADDataLengthKey NS_SWIFT_NAME(dataLength);
XADEXTERN XADArchiveKeys const XADSkipOffsetKey NS_SWIFT_NAME(skipOffset);
XADEXTERN XADArchiveKeys const XADSkipLengthKey NS_SWIFT_NAME(skipLength);

XADEXTERN XADArchiveKeys const XADIsSolidKey NS_SWIFT_NAME(isSolid);
XADEXTERN XADArchiveKeys const XADFirstSolidIndexKey NS_SWIFT_NAME(firstSolidIndex);
XADEXTERN XADArchiveKeys const XADFirstSolidEntryKey NS_SWIFT_NAME(firstSolidEntry);
XADEXTERN XADArchiveKeys const XADNextSolidIndexKey NS_SWIFT_NAME(nextSolidIndex);
XADEXTERN XADArchiveKeys const XADNextSolidEntryKey NS_SWIFT_NAME(nextSolidEntry);
XADEXTERN XADArchiveKeys const XADSolidObjectKey NS_SWIFT_NAME(solidObject);
XADEXTERN XADArchiveKeys const XADSolidOffsetKey NS_SWIFT_NAME(solidOffset);
XADEXTERN XADArchiveKeys const XADSolidLengthKey NS_SWIFT_NAME(solidLength);

// Archive properties only
XADEXTERN XADArchiveKeys const XADArchiveNameKey NS_SWIFT_NAME(archiveName);
XADEXTERN XADArchiveKeys const XADVolumesKey NS_SWIFT_NAME(volumes);
XADEXTERN XADArchiveKeys const XADVolumeScanningFailedKey NS_SWIFT_NAME(volumeScanningFailed);
XADEXTERN XADArchiveKeys const XADDiskLabelKey NS_SWIFT_NAME(diskLabel);

XADEXTERN XADArchiveKeys const XADSignatureOffset;
XADEXTERN XADArchiveKeys const XADParserClass;

@protocol XADArchiveParserDelegate;

XADEXPORT
@interface XADArchiveParser:NSObject
{
	CSHandle *sourcehandle;
	XADSkipHandle *skiphandle;
	XADResourceFork *resourcefork;

	id<XADArchiveParserDelegate> delegate;
	NSString *password;
	XADStringEncodingName passwordencodingname;
	BOOL caresaboutpasswordencoding;

	NSMutableDictionary *properties;
	XADStringSource *stringsource;

	int currindex;

	id parsersolidobj;
	NSMutableDictionary *firstsoliddict,*prevsoliddict;
	id currsolidobj;
	CSHandle *currsolidhandle;
	BOOL forcesolid;

	BOOL shouldstop;
}

+(void)initialize;
+(Class)archiveParserClassForHandle:(CSHandle *)handle firstBytes:(NSData *)header
resourceFork:(XADResourceFork *)fork name:(NSString *)name propertiesToAdd:(NSMutableDictionary *)props;
+ (Class)archiveParserFromParsersWithFloatingSignature:(NSArray *)parsers forHandle:(CSHandle *)handle firstBytes:(NSData *)header name:(NSString *)name propertiesToAdd:(NSMutableDictionary *)props;
+ (BOOL)isValidParserClass:(Class)parserClass forHandle:(CSHandle *)handle firstBytes:(NSData *)header name:(NSString *)name propertiesToAdd:(NSMutableDictionary *)props;

+(XADArchiveParser *)archiveParserForHandle:(CSHandle *)handle name:(NSString *)name;
+(XADArchiveParser *)archiveParserForHandle:(CSHandle *)handle name:(NSString *)name error:(XADError *)errorptr;
+(XADArchiveParser *)archiveParserForHandle:(CSHandle *)handle resourceFork:(XADResourceFork *)fork name:(NSString *)name;
+(XADArchiveParser *)archiveParserForHandle:(CSHandle *)handle resourceFork:(XADResourceFork *)fork name:(NSString *)name error:(XADError *)errorptr;
+(XADArchiveParser *)archiveParserForHandle:(CSHandle *)handle firstBytes:(NSData *)header name:(NSString *)name;
+(XADArchiveParser *)archiveParserForHandle:(CSHandle *)handle firstBytes:(NSData *)header name:(NSString *)name error:(XADError *)errorptr;
+(XADArchiveParser *)archiveParserForHandle:(CSHandle *)handle firstBytes:(NSData *)header resourceFork:(XADResourceFork *)fork name:(NSString *)name;
+(XADArchiveParser *)archiveParserForHandle:(CSHandle *)handle firstBytes:(NSData *)header resourceFork:(XADResourceFork *)fork name:(NSString *)name error:(XADError *)errorptr;
+(XADArchiveParser *)archiveParserForPath:(NSString *)filename;
+(XADArchiveParser *)archiveParserForPath:(NSString *)filename error:(XADError *)errorptr;
+(XADArchiveParser *)archiveParserForEntryWithDictionary:(NSDictionary *)entry archiveParser:(XADArchiveParser *)parser wantChecksum:(BOOL)checksum;
+(XADArchiveParser *)archiveParserForEntryWithDictionary:(NSDictionary *)entry archiveParser:(XADArchiveParser *)parser wantChecksum:(BOOL)checksum error:(XADError *)errorptr;
+(XADArchiveParser *)archiveParserForEntryWithDictionary:(NSDictionary *)entry resourceForkDictionary:(NSDictionary *)forkentry archiveParser:(XADArchiveParser *)parser wantChecksum:(BOOL)checksum;
+(XADArchiveParser *)archiveParserForEntryWithDictionary:(NSDictionary *)entry resourceForkDictionary:(NSDictionary *)forkentry archiveParser:(XADArchiveParser *)parser wantChecksum:(BOOL)checksum error:(XADError *)errorptr;
 
#pragma mark NSError functions
+(XADArchiveParser *)archiveParserForHandle:(CSHandle *)handle name:(NSString *)name nserror:(NSError **)errorptr NS_SWIFT_NAME(archiveParser(for:name:));
+(XADArchiveParser *)archiveParserForEntryWithDictionary:(NSDictionary *)entry
archiveParser:(XADArchiveParser *)parser wantChecksum:(BOOL)checksum nserror:(NSError **)errorptr
NS_SWIFT_NAME(archiveParser(with:archiveParser:wantChecksum:));
+(XADArchiveParser *)archiveParserForEntryWithDictionary:(NSDictionary *)entry
resourceForkDictionary:(NSDictionary *)forkentry archiveParser:(XADArchiveParser *)parser
wantChecksum:(BOOL)checksum nserror:(NSError **)errorptr
NS_SWIFT_NAME(archiveParser(with:resourceForkDictionary:archiveParser:wantChecksum:));
+(XADArchiveParser *)archiveParserForPath:(NSString *)filename nserror:(NSError **)errorptr
NS_SWIFT_NAME(archiveParser(forPath:));
+(XADArchiveParser *)archiveParserForHandle:(CSHandle *)handle firstBytes:(NSData *)header
resourceFork:(XADResourceFork *)fork name:(NSString *)name nserror:(NSError **)errorptr
NS_SWIFT_NAME(archiveParser(for:firstBytes:resourceFork:name:));
+(XADArchiveParser *)archiveParserForHandle:(CSHandle *)handle resourceFork:(XADResourceFork *)fork
name:(NSString *)name nserror:(NSError **)errorptr
NS_SWIFT_NAME(archiveParser(for:resourceFork:name:));
+(XADArchiveParser *)archiveParserForHandle:(CSHandle *)handle firstBytes:(NSData *)header
name:(NSString *)name nserror:(NSError **)errorptr
NS_SWIFT_NAME(archiveParser(for:firstBytes:name:));
+(XADArchiveParser *)archiveParserForFileURL:(NSURL *)filename error:(NSError **)errorptr
NS_SWIFT_NAME(archiveParser(for:));

-(id)init;
-(void)dealloc;

@property (nonatomic, retain) CSHandle *handle;
@property (retain) XADResourceFork *resourceFork;
@property (nonatomic, copy) NSString *name;
-(NSString *)filename;
-(void)setFilename:(NSString *)filename;
-(NSArray *)allFilenames;
-(void)setAllFilenames:(NSArray *)newnames;

@property (assign) id<XADArchiveParserDelegate> delegate;

@property (readonly, copy) NSDictionary *properties;
@property (nonatomic, readonly, copy) NSString *currentFilename;

@property (readonly, nonatomic, getter=isEncrypted) BOOL encrypted;
@property (nonatomic, copy) NSString *password;
@property (nonatomic, readonly) BOOL hasPassword;

@property (nonatomic, copy) XADStringEncodingName encodingName;
@property (nonatomic, readonly) float encodingConfidence;
@property (readonly) BOOL caresAboutPasswordEncoding;
@property (nonatomic, retain) XADStringEncodingName passwordEncodingName;
@property (readonly, retain) XADStringSource *stringSource;

-(XADString *)linkDestinationForDictionary:(NSDictionary *)dict;
-(XADString *)linkDestinationForDictionary:(NSDictionary *)dict error:(XADError *)errorptr;
-(NSDictionary *)extendedAttributesForDictionary:(NSDictionary *)dict;
-(NSData *)finderInfoForDictionary:(NSDictionary *)dict;

@property (readonly) BOOL wasStopped;

@property (nonatomic, readonly) BOOL hasChecksum;
-(BOOL)testChecksum NS_SWIFT_UNAVAILABLE("throws exception");
-(XADError)testChecksumWithoutExceptions;
-(BOOL)testChecksumWithError:(NSError**)error NS_REFINED_FOR_SWIFT;



// Internal functions

+(NSArray *)scanForVolumesWithFilename:(NSString *)filename regex:(XADRegex *)regex;
+(NSArray *)scanForVolumesWithFilename:(NSString *)filename
regex:(XADRegex *)regex firstFileExtension:(NSString *)firstext;

-(BOOL)shouldKeepParsing;

-(CSHandle *)handleAtDataOffsetForDictionary:(NSDictionary *)dict;
@property (readonly, retain) XADSkipHandle *skipHandle;
-(CSHandle *)zeroLengthHandleWithChecksum:(BOOL)checksum;
-(CSHandle *)subHandleFromSolidStreamForEntryWithDictionary:(NSDictionary *)dict;

@property (readonly) BOOL hasVolumes;
@property (readonly, copy) NSArray *volumeSizes;
@property (readonly, retain) CSHandle *currentHandle;

-(void)setObject:(id)object forPropertyKey:(XADArchiveKeys)key;
-(void)addPropertiesFromDictionary:(NSDictionary *)dict;
-(void)setIsMacArchive:(BOOL)ismac;

-(void)addEntryWithDictionary:(NSMutableDictionary *)dict;
-(void)addEntryWithDictionary:(NSMutableDictionary *)dict retainPosition:(BOOL)retainpos;

-(XADString *)XADStringWithString:(NSString *)string;
-(XADString *)XADStringWithData:(NSData *)data;
-(XADString *)XADStringWithData:(NSData *)data encodingName:(XADStringEncodingName)encoding;
-(XADString *)XADStringWithBytes:(const void *)bytes length:(NSInteger)length;
-(XADString *)XADStringWithBytes:(const void *)bytes length:(NSInteger)length encodingName:(XADStringEncodingName)encoding;
-(XADString *)XADStringWithCString:(const char *)cstring;
-(XADString *)XADStringWithCString:(const char *)cstring encodingName:(XADStringEncodingName)encoding;

@property (readonly, copy) XADPath *XADPath;
-(XADPath *)XADPathWithString:(NSString *)string;
-(XADPath *)XADPathWithUnseparatedString:(NSString *)string;
-(XADPath *)XADPathWithData:(NSData *)data separators:(const char *)separators;
-(XADPath *)XADPathWithData:(NSData *)data encodingName:(XADStringEncodingName)encoding separators:(const char *)separators;
-(XADPath *)XADPathWithBytes:(const void *)bytes length:(NSInteger)length separators:(const char *)separators;
-(XADPath *)XADPathWithBytes:(const void *)bytes length:(NSInteger)length encodingName:(XADStringEncodingName)encoding separators:(const char *)separators;
-(XADPath *)XADPathWithCString:(const char *)cstring separators:(const char *)separators;
-(XADPath *)XADPathWithCString:(const char *)cstring encodingName:(XADStringEncodingName)encoding separators:(const char *)separators;

-(NSData *)encodedPassword;
-(const char *)encodedCStringPassword;

-(void)reportInterestingFileWithReason:(NSString *)reason,... NS_FORMAT_FUNCTION(1,2);
-(void)reportInterestingFileWithReason:(NSString *)reason format:(va_list)args NS_FORMAT_FUNCTION(1,0);



// Subclasses implement these:
#if __has_feature(objc_class_property)
@property (class, readonly) int requiredHeaderSize;
#endif
+(int)requiredHeaderSize;
+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data
name:(NSString *)name;
+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data
name:(NSString *)name propertiesToAdd:(NSMutableDictionary *)props;
+(NSArray *)volumesForHandle:(CSHandle *)handle firstBytes:(NSData *)data
name:(NSString *)name;

-(void)parse;
-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum;
-(NSString *)formatName;

-(CSHandle *)handleForSolidStreamWithObject:(id)obj wantChecksum:(BOOL)checksum;

// Exception-free wrappers for subclass methods:
// parseWithoutExceptions will in addition return XADBreakError if the delegate
// requested parsing to stop.

-(XADError)parseWithoutExceptions;
-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum error:(XADError *)errorptr;

//! Exception-free wrapper for subclass method.<br>
//! Will, in addition, pass `XADErrorBreak` and return `NO` if the delegate
//! requested parsing to stop.
-(BOOL)parseWithError:(NSError**)error;
//! Exception-free wrapper for subclass method.
-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum nserror:(NSError **)errorptr ;

@end

@protocol XADArchiveParserDelegate <NSObject>
@optional

-(void)archiveParser:(XADArchiveParser *)parser foundEntryWithDictionary:(NSDictionary *)dict;
-(BOOL)archiveParsingShouldStop:(XADArchiveParser *)parser;
-(void)archiveParserNeedsPassword:(XADArchiveParser *)parser;
-(void)archiveParser:(XADArchiveParser *)parser findsFileInterestingForReason:(NSString *)reason;

@end
