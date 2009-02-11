#import "XADArchiveParser.h"

extern NSString *XADIsMacBinaryKey;

@interface XADDittoParser:XADArchiveParser
{
}

-(void)addEntryWithDictionary:(NSDictionary *)dictionary;

//-(BOOL)_isDittoResourceFork:(NSDictionary *)properties;
//-(NSString *)_entryIndexOfDataForkForDittoResourceFork:(NSDictionary *)properties;

@end
