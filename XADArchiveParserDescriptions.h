#import "XADArchiveParser.h"

@interface XADArchiveParser (Descriptions)

-(NSString *)descriptionOfValueInDictionary:(NSDictionary *)dict key:(NSString *)key;
-(NSString *)descriptionOfKey:(NSString *)key;
-(NSArray *)descriptiveOrderingOfKeysInDictionary:(NSDictionary *)dict;

@end

NSString *XADHumanReadableFileSize(uint64_t size);
NSString *XADShortHumanReadableFileSize(uint64_t size);
NSString *XADHumanReadableDate(NSDate *date);
NSString *XADHumanReadableBoolean(uint64_t boolean);
NSString *XADHumanReadablePOSIXPermissions(uint64_t permissions);
NSString *XADHumanReadableOSType(uint64_t ostype);
NSString *XADHumanReadableData(NSData *data);
NSString *XADHumanReadableExtendedAttributes(NSDictionary *dict);
