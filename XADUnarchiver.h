#import <Foundation/Foundation.h>

#import "XADArchiveParser.h"

#define XADIgnoredForkStyle 0
#define XADMacOSXForkStyle 1
#define XADHiddenAppleDoubleForkStyle 2
#define XADVisibleAppleDoubleForkStyle 3

#ifdef __APPLE__
#define XADDefaultForkStyle XADMacOSXForkStyle
#else
#define XADDefaultForkStyle XADVisibleAppleDoubleForkStyle
#endif

@interface XADUnarchiver:NSObject
{
	XADArchiveParser *parser;
	NSString *destination;
	int forkstyle;
	double updateinterval;

	id delegate;

	NSMutableArray *deferreddirectories;
}

+(XADUnarchiver *)unarchiverForArchiveParser:(XADArchiveParser *)archiveparser;
+(XADUnarchiver *)unarchiverForPath:(NSString *)path;

-(id)initWithArchiveParser:(XADArchiveParser *)archiveparser;
-(void)dealloc;

-(id)delegate;
-(void)setDelegate:(id)newdelegate;

//-(NSString *)password;
//-(void)setPassword:(NSString *)password;

//-(NSStringEncoding)encoding;
//-(void)setEncoding:(NSStringEncoding)encoding;

-(NSString *)destination;
-(void)setDestination:(NSString *)destinationpath;

-(int)macResourceForkStyle;
-(void)setMacResourceForkStyle:(int)forkhandling;

-(XADError)parseAndUnarchive;

-(XADError)extractEntryWithDictionary:(NSDictionary *)dict;
-(XADError)extractEntryWithDictionary:(NSDictionary *)dict forceDirectories:(BOOL)force;
-(XADError)extractEntryWithDictionary:(NSDictionary *)dict as:(NSString *)path;
-(XADError)extractEntryWithDictionary:(NSDictionary *)dict as:(NSString *)path forceDirectories:(BOOL)force;
-(XADError)finishExtractions;

-(XADError)_extractFileEntryWithDictionary:(NSDictionary *)dict as:(NSString *)destpath;
-(XADError)_extractResourceForkEntryWithDictionary:(NSDictionary *)dict asMacForkForFile:(NSString *)destpath;
-(XADError)_extractResourceForkEntryWithDictionary:(NSDictionary *)dict asAppleDoubleFile:(NSString *)destpath;
-(XADError)_extractDirectoryEntryWithDictionary:(NSDictionary *)dict as:(NSString *)destpath;
-(XADError)_extractLinkEntryWithDictionary:(NSDictionary *)dict as:(NSString *)destpath;
-(XADError)_extractEntryWithDictionary:(NSDictionary *)dict toFileHandle:(int)fh;

-(XADError)_updateFileAttributesAtPath:(NSString *)path forEntryWithDictionary:(NSDictionary *)dict
deferDirectories:(BOOL)defer;
-(XADError)_ensureDirectoryExists:(NSString *)path;

@end



@interface NSObject (XADUnarchiverDelegate)

-(void)unarchiverNeedsPassword:(XADUnarchiver *)unarchiver;

-(NSString *)unarchiver:(XADUnarchiver *)unarchiver pathForExtractingEntryWithDictionary:(NSDictionary *)dict;
-(BOOL)unarchiver:(XADUnarchiver *)unarchiver shouldStartExtractingEntryWithDictionary:(NSDictionary *)dict to:(NSString *)path;
-(void)unarchiver:(XADUnarchiver *)unarchiver willStartExtractingEntryWithDictionary:(NSDictionary *)dict to:(NSString *)path;
-(void)unarchiver:(XADUnarchiver *)unarchiver finishedExtractingEntryWithDictionary:(NSDictionary *)dict to:(NSString *)path;
-(void)unarchiver:(XADUnarchiver *)unarchiver failedToExtractEntryWithDictionary:(NSDictionary *)dict to:(NSString *)path error:(XADError)error;

-(BOOL)unarchiver:(XADUnarchiver *)unarchiver shouldCreateDirectory:(NSString *)directory;
-(BOOL)unarchiver:(XADUnarchiver *)unarchiver shouldExtractArchiveEntryWithDictionary:(NSDictionary *)dict to:(NSString *)path;

-(NSString *)unarchiver:(XADUnarchiver *)unarchiver linkDestinationForEntryWithDictionary:(NSDictionary *)dict from:(NSString *)path;
//-(XADAction)unarchiver:(XADUnarchiver *)unarchiver creatingDirectoryDidFailForEntry:(int)n;

-(BOOL)extractionShouldStopForUnarchiver:(XADUnarchiver *)unarchiver;
-(void)unarchiver:(XADUnarchiver *)unarchiver extractionProgressForEntryWithDictionary:(NSDictionary *)dict
fileFraction:(double)fileprogress estimatedTotalFraction:(double)totalprogress;

@end
