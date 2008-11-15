#import "XADArchive.h"

@interface XADBinHexArchive:XADArchive
{
}

+(int)requiredHeaderSize;
+(BOOL)canOpenFile:(NSString *)filename handle:(CSHandle *)handle firstBytes:(NSData *)data;

-(id)initWithFile:(NSString *)filename handle:(CSHandle *)handle;
-(void)scan;
-(CSHandle *)handleForEntryWithProperties:(NSDictionary *)properties;
-(CSHandle *)resourceHandleEntryWithProperties:(NSDictionary *)properties;

-(NSString *)formatName;

@end
