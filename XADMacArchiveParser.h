#import "XADArchiveParser.h"

extern NSString *XADIsMacBinaryKey;

@interface XADMacArchiveParser:XADArchiveParser
{
	CSHandle *dittohandle;
}

-(id)initWithHandle:(CSHandle *)handle name:(NSString *)name;

-(void)addEntryWithDictionary:(NSMutableDictionary *)dict retainPosition:(BOOL)retainpos;
-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum;

-(BOOL)isDittoResourceFork:(NSMutableDictionary *)dict;
-(NSMutableDictionary *)parseAppleDoubleWithHandle:(CSHandle *)fh template:(NSDictionary *)template;

-(CSHandle *)rawHandleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum;

@end
