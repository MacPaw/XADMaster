#import "XADUnarchiver.h"

@interface XADPlatform:NSObject {}

+(XADError)extractResourceForkEntryWithDictionary:(NSDictionary *)dict
unarchiver:(XADUnarchiver *)unarchiver toPath:(NSString *)destpath;

+(XADError)updateFileAttributesAtPath:(NSString *)path
forEntryWithDictionary:(NSDictionary *)dict parser:(XADArchiveParser *)parser
preservePermissions:(BOOL)preservepermissions;

+(XADError)createLinkAtPath:(NSString *)path withDestinationPath:(NSString *)link;

+(double)currentTimeInSeconds;

@end
