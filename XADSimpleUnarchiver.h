#import <Foundation/Foundation.h>

#import "XADArchiveParser.h"
#import "XADUnarchiver.h"
#import "XADRegex.h"

#define XADNeverCreateEnclosingDirectory 0
#define XADAlwaysCreateEnclosingDirectory 1
#define XADCreateEnclosingDirectoryWhenNeeded 2

@interface XADSimpleUnarchiver:NSObject
{
	XADArchiveParser *parser;
	XADUnarchiver *unarchiver,*subunarchiver;

	id delegate;
	BOOL shouldstop;

	NSString *destination,*enclosingdir;
	BOOL extractsubarchives,removesolo;
	BOOL overwrite,rename,skip;
	BOOL updateenclosing,updatesolo;
	BOOL propagatemetadata;

	NSMutableArray *regexes;
	NSMutableIndexSet *indices;

	NSMutableArray *entries,*reasonsforinterest;
	NSMutableDictionary *renames;
	NSMutableSet *resourceforks;
	id metadata;
	NSString *actualdestination,*finaldestination;
	BOOL enclosingcollision;

	off_t totalsize,currsize,totalprogress;
}

+(XADSimpleUnarchiver *)simpleUnarchiverForPath:(NSString *)path;
+(XADSimpleUnarchiver *)simpleUnarchiverForPath:(NSString *)path error:(XADError *)errorptr;

-(id)initWithArchiveParser:(XADArchiveParser *)archiveparser;
-(void)dealloc;

-(XADArchiveParser *)archiveParser;
-(XADArchiveParser *)outerArchiveParser;
-(XADArchiveParser *)innerArchiveParser;
-(NSArray *)reasonsForInterest;

-(id)delegate;
-(void)setDelegate:(id)newdelegate;

// TODO: Encoding wrappers?

-(NSString *)password;
-(void)setPassword:(NSString *)password;

-(NSString *)destination;
-(void)setDestination:(NSString *)destpath;

-(NSString *)enclosingDirectoryName;
-(void)setEnclosingDirectoryName:(NSString *)dirname;

-(BOOL)removesEnclosingDirectoryForSoloItems;
-(void)setRemovesEnclosingDirectoryForSoloItems:(BOOL)removeflag;

-(BOOL)alwaysOverwritesFiles;
-(void)setAlwaysOverwritesFiles:(BOOL)overwriteflag;

-(BOOL)alwaysRenamesFiles;
-(void)setAlwaysRenamesFiles:(BOOL)renameflag;

-(BOOL)alwaysSkipsFiles;
-(void)setAlwaysSkipsFiles:(BOOL)skipflag;

-(BOOL)updatesEnclosingDirectoryModificationTime;
-(void)setUpdatesEnclosingDirectoryModificationTime:(BOOL)modificationflag;

-(BOOL)updatesSoloItemModificationTime;
-(void)setUpdatesSoloItemModificationTime:(BOOL)modificationflag;

-(BOOL)extractsSubArchives;
-(void)setExtractsSubArchives:(BOOL)extractflag;

-(BOOL)propagatesRelevantMetadata;
-(void)setPropagatesRelevantMetadata:(BOOL)propagateflag;

-(int)macResourceForkStyle;
-(void)setMacResourceForkStyle:(int)style;

-(BOOL)preservesPermissions;
-(void)setPreserevesPermissions:(BOOL)preserveflag;

-(double)updateInterval;
-(void)setUpdateInterval:(double)interval;

-(void)addGlobFilter:(NSString *)wildcard;
-(void)addRegexFilter:(XADRegex *)regex;
-(void)addIndexFilter:(int)index;

-(NSString *)actualDestinationPath;


-(XADError)parseAndUnarchive;

-(XADError)parse;
-(XADError)_setupSubArchiveForEntryWithDictionary:(NSDictionary *)dict;

-(XADError)unarchive;
-(XADError)_unarchiveRegularArchive;
-(XADError)_unarchiveSubArchive;

-(void)_finalizeExtraction;

-(NSString *)_checkPath:(NSString *)path forEntryWithDictionary:(NSDictionary *)dict deferred:(BOOL)deferred;
-(NSString *)_findUniquePathForCollidingPath:(NSString *)path;
-(BOOL)_fileExistsAtPath:(NSString *)path;
-(BOOL)_fileExistsAtPath:(NSString *)path isDirectory:(BOOL *)isdirptr;
-(NSArray *)_contentsOfDirectoryAtPath:(NSString *)path;
-(BOOL)_moveItemAtPath:(NSString *)src toPath:(NSString *)dest;
-(BOOL)_removeItemAtPath:(NSString *)path;
-(BOOL)_recursivelyMoveItemAtPath:(NSString *)src toPath:(NSString *)dest overwrite:(BOOL)overwritethislevel;
-(BOOL)_shouldStop;

@end



@interface NSObject (XADSimpleUnarchiverDelegate)

-(void)simpleUnarchiverNeedsPassword:(XADSimpleUnarchiver *)unarchiver;

-(NSString *)simpleUnarchiver:(XADSimpleUnarchiver *)unarchiver encodingNameForXADPath:(XADPath *)path;
-(NSString *)simpleUnarchiver:(XADSimpleUnarchiver *)unarchiver encodingNameForXADString:(XADString *)string;

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
