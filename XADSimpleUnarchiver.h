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
	BOOL extractsubarchives,removesolo,overwrite,rename;

	NSMutableArray *regexes;
	NSMutableIndexSet *indices;

	NSMutableArray *entries,*reasonsforinterest;

	off_t totalsize,currsize,totalprogress;
}

+(XADSimpleUnarchiver *)simpleUnarchiverForPath:(NSString *)path;
+(XADSimpleUnarchiver *)simpleUnarchiverForPath:(NSString *)path error:(XADError *)errorptr;

-(id)initWithArchiveParser:(XADArchiveParser *)archiveparser;
-(void)dealloc;

-(XADArchiveParser *)archiveParser;
-(NSArray *)reasonsForInterest;

-(id)delegate;
-(void)setDelegate:(id)newdelegate;

// TODO: Encoding wrappers?

-(NSString *)password;
-(void)setPassword:(NSString *)password;

-(NSString *)destination;
-(void)setDestination:(NSString *)destpath;

-(NSString *)enclosingDirectoryName;
-(NSString *)enclosingDirectoryPath;
-(void)setEnclosingDirectoryName:(NSString *)dirname;

-(BOOL)removesEnclosingDirectoryForSoloItems;
-(void)setRemovesEnclosingDirectoryForSoloItems:(BOOL)removeflag;

-(BOOL)alwaysOverwritesFiles;
-(void)setAlwaysOverwritesFiles:(BOOL)overwriteflag;

-(BOOL)alwaysRenamesFiles;
-(void)setAlwaysRenamesFiles:(BOOL)renameflag;

-(BOOL)extractsSubArchives;
-(void)setExtractsSubArchives:(BOOL)extractflag;

-(int)macResourceForkStyle;
-(void)setMacResourceForkStyle:(int)style;

-(BOOL)preservesPermissions;
-(void)setPreserevesPermissions:(BOOL)preserveflag;

-(double)updateInterval;
-(void)setUpdateInterval:(double)interval;

-(void)addGlobFilter:(NSString *)wildcard;
-(void)addRegexFilter:(XADRegex *)regex;
-(void)addIndexFilter:(int)index;

-(XADError)parseAndUnarchive;

-(XADError)_handleRegularArchive;
-(XADError)_handleSubArchiveWithEntry:(NSDictionary *)entry;
-(void)_finalizeExtraction;

-(BOOL)_shouldStop;
-(NSString *)_filenameForEntryWithDictionary:(NSDictionary *)dict;
-(NSString *)_findUniquePathForCollidingPath:(NSString *)path;

@end



@interface NSObject (XADSimpleUnarchiverDelegate)

-(void)simpleUnarchiverNeedsPassword:(XADSimpleUnarchiver *)unarchiver;

-(NSString *)simpleUnarchiver:(XADSimpleUnarchiver *)unarchiver encodingNameForXADString:(XADString *)string;

-(NSString *)simpleUnarchiver:self replacementPathForEntryWithDictionary:(NSDictionary *)dict
originalPath:(NSString *)path suggestedPath:(NSString *)unique;

-(BOOL)simpleUnarchiver:(XADSimpleUnarchiver *)unarchiver shouldExtractEntryWithDictionary:(NSDictionary *)dict to:(NSString *)path;
-(void)simpleUnarchiver:(XADSimpleUnarchiver *)unarchiver willExtractEntryWithDictionary:(NSDictionary *)dict to:(NSString *)path;
-(void)simpleUnarchiver:(XADSimpleUnarchiver *)unarchiver didExtractEntryWithDictionary:(NSDictionary *)dict to:(NSString *)path error:(XADError)error;

-(BOOL)extractionShouldStopForSimpleUnarchiver:(XADSimpleUnarchiver *)unarchiver;

-(void)simpleUnarchiver:(XADSimpleUnarchiver *)unarchiver
extractionProgressForEntryWithDictionary:(NSDictionary *)dict
fileProgress:(off_t)fileprogress of:(off_t)filesize
totalProgress:(off_t)totalprogress of:(off_t)totalsize;
-(void)simpleUnarchiver:(XADSimpleUnarchiver *)unarchiver
estimatedExtractionProgressForEntryWithDictionary:(NSDictionary *)dict
fileProgress:(double)fileprogress totalProgress:(double)totalprogress;

@end
