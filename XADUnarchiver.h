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

-(void)parseAndUnarchive;

-(XADError)extractEntryWithDictionary:(NSDictionary *)dict;

-(XADError)_extractFileEntryWithDictionary:(NSDictionary *)dict as:(NSString *)destpath;
-(XADError)_extractResourceForkEntryWithDictionary:(NSDictionary *)dict asMacForkForFile:(NSString *)destpath;
-(XADError)_extractResourceForkEntryWithDictionary:(NSDictionary *)dict asAppleDoubleFile:(NSString *)destpath;
-(XADError)_extractDirectoryEntryWithDictionary:(NSDictionary *)dict as:(NSString *)destpath;
-(XADError)_extractLinkEntryWithDictionary:(NSDictionary *)dict as:(NSString *)destpath;
-(XADError)_extractEntryWithDictionary:(NSDictionary *)dict toFileHandle:(int)fh;

-(XADError)_updateFileAttributesAtPath:(NSString *)path forEntryWithDictionary:(NSDictionary *)dict;
-(XADError)_ensureFileExists:(NSString *)path;
-(XADError)_ensureDirectoryExists:(NSString *)path;

@end



@interface NSObject (XADUnarchiverDelegate)

-(void)unarchiverNeedsPassword:(XADUnarchiver *)unarchiver;

-(NSString *)unarchiver:(XADUnarchiver *)unarchiver pathForExtractingEntryWithDictionary:(NSDictionary *)dict;
-(BOOL)unarchiver:(XADUnarchiver *)unarchiver shouldStartExtractingEntryWithDictionary:(NSDictionary *)dict to:(NSString *)path;
-(void)unarchiver:(XADUnarchiver *)unarchiver willStartExtractingEntryWithDictionary:(NSDictionary *)dict to:(NSString *)path;
-(void)unarchiver:(XADUnarchiver *)unarchiver finishedExtractingEntryWithDictionary:(NSDictionary *)dict to:(NSString *)path;
-(void)unarchiver:(XADUnarchiver *)unarchiver failedToExtractEntryWithDictionary:(NSDictionary *)dict to:(NSString *)path error:(XADError)error;

//-(NSStringEncoding)unarchiver:(XADUnarchiver *)unarchiver encodingForString:(XADString *)data guess:(NSStringEncoding)guess confidence:(float)confidence;

//-(XADAction)archive:(XADArchive *)archive nameDecodingDidFailForEntry:(int)n data:(NSData *)data;

-(BOOL)unarchiver:(XADUnarchiver *)unarchiver shouldCreateDirectory:(NSString *)directory;
//			if(!delegate||[delegate unarchiver:self shouldCreateDirectory:directory])
//-(XADAction)unarchiver:(XADUnarchiver *)unarchiver creatingDirectoryDidFailForEntry:(int)n;

-(BOOL)extractionShouldStopForUnarchiver:(XADUnarchiver *)unarchiver;
-(void)unarchiver:(XADUnarchiver *)unarchiver extractionProgressForEntryWithDictionary:(NSDictionary *)dict
fileFraction:(double)fileprogress estimatedTotalFraction:(double)totalprogress;

/*-(XADAction)archive:(XADArchive *)archive entry:(int)n collidesWithFile:(NSString *)file newFilename:(NSString **)newname;
-(XADAction)archive:(XADArchive *)archive entry:(int)n collidesWithDirectory:(NSString *)file newFilename:(NSString **)newname;

*/


-(void)unarchiver:(XADUnarchiver *)unarchiver progressReportForEntry:(NSDictionary *)dict fileProgress:(double)fileprogress totalProgress:(double)totalprogress;

@end
