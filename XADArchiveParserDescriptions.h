#import "XADArchiveParser.h"

@interface XADArchiveParser (Descriptions)

-(NSString *)descriptionOfEntryInDictionary:(NSDictionary *)dict key:(NSString *)key;
-(NSString *)descriptionOfKey:(NSString *)key;

@end
