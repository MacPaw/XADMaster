#import "XADArchive.h"

@interface XADBZip2Archive:XADArchive
{
}

+(int)requiredHeaderSize;
+(BOOL)canOpenFile:(NSString *)filename handle:(CSHandle *)handle firstBytes:(NSData *)data;

-(id)initWithFile:(NSString *)filename handle:(CSHandle *)handle;
-(void)scan;
-(CSHandle *)handleForEntryWithProperties:(NSDictionary *)properties;

-(NSString *)formatName;

@end
