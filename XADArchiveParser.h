#import <Foundation/Foundation.h>
#import "XADException.h"
#import "XADString.h"
#import "XADRegex.h"
#import "CSHandle.h"
#import "XADSkipHandle.h"
#import "Checksums.h"

extern NSString *XADFileNameKey;
extern NSString *XADFileSizeKey;
extern NSString *XADCompressedSizeKey;
extern NSString *XADLastModificationDateKey;
extern NSString *XADLastAccessDateKey;
extern NSString *XADCreationDateKey;
extern NSString *XADFileTypeKey;
extern NSString *XADFileCreatorKey;
extern NSString *XADFinderFlagsKey;
extern NSString *XADPosixPermissionsKey;
extern NSString *XADPosixUserKey;
extern NSString *XADPosixGroupKey;
extern NSString *XADPosixUserNameKey;
extern NSString *XADPosixGroupNameKey;
extern NSString *XADDOSFileAttributesKey;
extern NSString *XADWindowsFileAttributesKey;
extern NSString *XADIsEncryptedKey;
extern NSString *XADIsDirectoryKey;
extern NSString *XADIsResourceForkKey;
extern NSString *XADIsMacBinaryKey;
extern NSString *XADLinkDestinationKey;
extern NSString *XADCommentKey;
extern NSString *XADDataOffsetKey;
extern NSString *XADDataLengthKey;
extern NSString *XADCompressionNameKey;
extern NSString *XADIsSolidKey;

// Internal use
extern NSString *XADResourceDataKey;
extern NSString *XADDittoPropertiesKey;

// Deprecated
extern NSString *XADResourceForkData;
extern NSString *XADFinderFlags;

@interface XADArchiveParser:NSObject
{
	CSHandle *sourcehandle;
	XADSkipHandle *skiphandle;
	NSString *archivename;

	id delegate;
	NSString *password;

	BOOL isencrypted;

	XADStringSource *stringsource;
}

+(void)initialize;
+(XADArchiveParser *)archiveParserForHandle:(CSHandle *)handle name:(NSString *)name;
+(XADArchiveParser *)archiveParserForPath:(NSString *)filename;
+(NSArray *)volumesForFilename:(NSString *)name;

-(id)initWithHandle:(CSHandle *)handle name:(NSString *)name;
-(void)dealloc;

-(id)delegate;
-(void)setDelegate:(id)newdelegate;

-(BOOL)isEncrypted;
-(void)setPassword:(NSString *)newpassword;
-(NSString *)password;

// Internal functions

-(NSString *)name;
-(CSHandle *)handle;
-(CSHandle *)handleAtDataOffsetForDictionary:(NSDictionary *)dict;
-(XADSkipHandle *)skipHandle;

-(NSArray *)volumes;
-(off_t)offsetForVolume:(int)disk offset:(off_t)offset;

-(void)addEntryWithDictionary:(NSDictionary *)dictionary;
-(void)addEntryWithDictionary:(NSDictionary *)dictionary retainPosition:(BOOL)retainpos;

-(XADString *)XADStringWithString:(NSString *)string;
-(XADString *)XADStringWithData:(NSData *)data;
-(XADString *)XADStringWithData:(NSData *)data encoding:(NSStringEncoding)encoding;
-(XADString *)XADStringWithBytes:(void *)bytes length:(int)length;
-(XADString *)XADStringWithBytes:(void *)bytes length:(int)length encoding:(NSStringEncoding)encoding;
-(XADString *)XADStringWithCString:(void *)string;
-(XADString *)XADStringWithCString:(void *)string encoding:(NSStringEncoding)encoding;

-(void)setEncrypted:(BOOL)encryptedflag;
-(NSData *)encodedPassword;
-(char *)encodedCStringPassword;


// Subclasses implement these:

+(int)requiredHeaderSize;
+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name;
+(XADRegex *)volumeRegexForFilename:(NSString *)filename;
+(BOOL)isFirstVolume:(NSString *)filename;

-(void)parse;
-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dictionary wantChecksum:(BOOL)checksum;
-(NSString *)formatName;

@end

@interface NSObject (XADArchiveParserDelegate)

-(void)archiveParser:(XADArchiveParser *)parser foundEntryWithDictionary:(NSDictionary *)dict;
-(BOOL)archiveParsingShouldStop:(XADArchiveParser *)parser;

@end

NSMutableArray *XADSortVolumes(NSMutableArray *volumes,NSString *firstfileextension);
