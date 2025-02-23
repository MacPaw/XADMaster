/*
 * XADSimpleUnarchiver.h
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
#import "XADRegex.h"
#pragma clang diagnostic pop

#define XADNeverCreateEnclosingDirectory 0
#define XADAlwaysCreateEnclosingDirectory 1
#define XADCreateEnclosingDirectoryWhenNeeded 2

@protocol XADSimpleUnarchiverDelegate;

XADEXPORT
@interface XADSimpleUnarchiver:NSObject <XADArchiveParserDelegate, XADUnarchiverDelegate>
{
	XADArchiveParser *parser;
	XADUnarchiver *unarchiver,*subunarchiver;

	id<XADSimpleUnarchiverDelegate> delegate;
	BOOL shouldstop;

	NSString *destination,*enclosingdir;
	BOOL extractsubarchives,removesolo;
	BOOL overwrite,rename,skip;
	BOOL copydatetoenclosing,copydatetosolo,resetsolodate;
	BOOL propagatemetadata;

	NSMutableArray *regexes;
	NSMutableIndexSet *indices;

	NSMutableArray *entries,*reasonsforinterest;
	NSMutableDictionary *renames;
	NSMutableSet *resourceforks;
	id metadata;
	NSString *unpackdestination,*finaldestination,*overridesoloitem;
	NSInteger numextracted;

	NSString *toplevelname;
	BOOL lookslikesolo;

	off_t totalsize,currsize,totalprogress;
}

+(XADSimpleUnarchiver *)simpleUnarchiverForPath:(NSString *)path;
+(XADSimpleUnarchiver *)simpleUnarchiverForPath:(NSString *)path error:(XADError *)errorptr;

-(id)initWithArchiveParser:(XADArchiveParser *)archiveparser;
-(id)initWithArchiveParser:(XADArchiveParser *)archiveparser entries:(NSArray *)entryarray;
-(void)dealloc;

-(XADArchiveParser *)archiveParser;
-(XADArchiveParser *)outerArchiveParser;
-(XADArchiveParser *)innerArchiveParser;
-(NSArray *)reasonsForInterest;

@property (assign) id<XADSimpleUnarchiverDelegate> delegate;

// TODO: Encoding wrappers?

-(NSString *)password;
-(void)setPassword:(NSString *)password;

@property (nonatomic, copy) NSString *destination;

@property (nonatomic, copy) NSString *enclosingDirectoryName;

@property BOOL removesEnclosingDirectoryForSoloItems;

@property BOOL alwaysOverwritesFiles;

@property BOOL alwaysRenamesFiles;

@property BOOL alwaysSkipsFiles;

@property BOOL extractsSubArchives;

@property BOOL copiesArchiveModificationTimeToEnclosingDirectory;

@property BOOL copiesArchiveModificationTimeToSoloItems;

@property BOOL resetsDateForSoloItems;

@property BOOL propagatesRelevantMetadata;

@property (nonatomic) XADForkStyle macResourceForkStyle;

@property (nonatomic) BOOL preservesPermissions;
-(void)setPreserevesPermissions:(BOOL)preserveflag API_DEPRECATED_WITH_REPLACEMENT("-setPreservesPermissions:", macosx(10.0, 10.8), ios(3.0, 8.0));

@property (nonatomic) NSTimeInterval updateInterval;

-(void)addGlobFilter:(NSString *)wildcard;
-(void)addRegexFilter:(XADRegex *)regex;
-(void)addIndexFilter:(NSInteger)index;
-(void)setIndices:(NSIndexSet *)indices;

-(off_t)predictedTotalSize;
-(off_t)predictedTotalSizeIgnoringUnknownFiles:(BOOL)ignoreunknown;

@property (readonly) NSInteger numberOfItemsExtracted;
@property (readonly) BOOL wasSoloItem;
@property (readonly, copy) NSString *actualDestination;
-(NSString *)soloItem;
-(NSString *)createdItem;
-(NSString *)createdItemOrActualDestination;



-(XADError)parse;
-(XADError)_setupSubArchiveForEntryWithDataFork:(NSDictionary *)datadict resourceFork:(NSDictionary *)resourcedict;
-(BOOL)_setupSubArchiveForEntryWithDataFork:(NSDictionary *)datadict resourceFork:(NSDictionary *)resourcedict error:(NSError**)outError;

-(XADError)unarchive;
-(XADError)_unarchiveRegularArchive;
-(XADError)_unarchiveSubArchive;

-(XADError)_finalizeExtraction;

-(void)_testForSoloItems:(NSDictionary *)entry;

-(BOOL)_shouldStop;

-(NSString *)_checkPath:(NSString *)path forEntryWithDictionary:(NSDictionary *)dict deferred:(BOOL)deferred;
-(BOOL)_recursivelyMoveItemAtPath:(NSString *)src toPath:(NSString *)dest overwrite:(BOOL)overwritethislevel;

+(NSString *)_findUniquePathForOriginalPath:(NSString *)path;
+(NSString *)_findUniquePathForOriginalPath:(NSString *)path reservedPaths:(NSSet *)reserved;

@end



@protocol XADSimpleUnarchiverDelegate <NSObject>
@optional
-(void)simpleUnarchiverNeedsPassword:(XADSimpleUnarchiver *)unarchiver;

-(CSHandle *)simpleUnarchiver:(XADSimpleUnarchiver *)unarchiver outputHandleForEntryWithDictionary:(NSDictionary *)dict;

-(XADStringEncodingName)simpleUnarchiver:(XADSimpleUnarchiver *)unarchiver encodingNameForXADString:(id <XADString>)string;

-(BOOL)simpleUnarchiver:(XADSimpleUnarchiver *)unarchiver shouldExtractEntryWithDictionary:(NSDictionary *)dict to:(NSString *)path;
-(void)simpleUnarchiver:(XADSimpleUnarchiver *)unarchiver willExtractEntryWithDictionary:(NSDictionary *)dict to:(NSString *)path;
-(void)simpleUnarchiver:(XADSimpleUnarchiver *)unarchiver didExtractEntryWithDictionary:(NSDictionary *)dict to:(NSString *)path error:(XADError)error;

-(NSString *)simpleUnarchiver:(XADSimpleUnarchiver *)unarchiver replacementPathForEntryWithDictionary:(NSDictionary *)dict
originalPath:(NSString *)path suggestedPath:(NSString *)unique;
-(NSString *)simpleUnarchiver:(XADSimpleUnarchiver *)unarchiver deferredReplacementPathForOriginalPath:(NSString *)path
suggestedPath:(NSString *)unique;

-(BOOL)extractionShouldStopForSimpleUnarchiver:(XADSimpleUnarchiver *)unarchiver;

-(void)simpleUnarchiver:(XADSimpleUnarchiver *)unarchiver
extractionProgressForEntryWithDictionary:(NSDictionary *)dict
fileProgress:(off_t)fileprogress of:(off_t)filesize
totalProgress:(off_t)totalprogress of:(off_t)totalsize;
-(void)simpleUnarchiver:(XADSimpleUnarchiver *)unarchiver
estimatedExtractionProgressForEntryWithDictionary:(NSDictionary *)dict
fileProgress:(double)fileprogress totalProgress:(double)totalprogress;

@end
