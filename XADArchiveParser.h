#import <Foundation/Foundation.h>
#import "XADException.h"
#import "XADString.h"
#import "XADRegex.h"
#import "CSHandle.h"
#import "XADSkipHandle.h"

extern const NSString *XADFileNameKey;
extern const NSString *XADFileSizeKey;
extern const NSString *XADCompressedSizeKey;
extern const NSString *XADLastModificationDateKey;
extern const NSString *XADLastAccessDateKey;
extern const NSString *XADCreationDateKey;
extern const NSString *XADFileTypeKey;
extern const NSString *XADFileCreatorKey;
extern const NSString *XADFinderFlagsKey;
extern const NSString *XADPosixPermissionsKey;
extern const NSString *XADPosixUserKey;
extern const NSString *XADPosixGroupKey;
extern const NSString *XADPosixUserNameKey;
extern const NSString *XADPosixGroupNameKey;
extern const NSString *XADIsEncryptedKey;
extern const NSString *XADIsDirectoryKey;
extern const NSString *XADIsResourceForkKey;
extern const NSString *XADIsMacBinaryKey;
extern const NSString *XADLinkDestinationKey;
extern const NSString *XADCommentKey;
extern const NSString *XADDataOffsetKey;
extern const NSString *XADDataLengthKey;
extern const NSString *XADCompressionNameKey;

// Internal use
extern const NSString *XADResourceDataKey;
extern const NSString *XADDittoPropertiesKey;

// Deprecated
extern const NSString *XADResourceForkData;
extern const NSString *XADFinderFlags;

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
-(XADString *)XADStringWithBytes:(const void *)bytes length:(int)length;
-(XADString *)XADStringWithBytes:(const void *)bytes length:(int)length encoding:(NSStringEncoding)encoding;
-(XADString *)XADStringWithCString:(const void *)string;
-(XADString *)XADStringWithCString:(const void *)string encoding:(NSStringEncoding)encoding;

-(void)setEncrypted:(BOOL)encryptedflag;
-(NSData *)encodedPassword;
-(const char *)encodedCStringPassword;


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
