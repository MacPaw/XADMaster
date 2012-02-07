#import "XADArchiveParser.h"

@interface XADArchiveParser (Descriptions)

-(NSString *)descriptionOfValueInDictionary:(NSDictionary *)dict key:(NSString *)key;
-(NSString *)descriptionOfKey:(NSString *)key;
-(NSArray *)descriptiveOrderingOfKeysInDictionary:(NSDictionary *)dict;

@end
