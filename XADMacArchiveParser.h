#import "XADArchiveParser.h"
#import "XADRegex.h"

extern NSString *XADIsMacBinaryKey;

@interface XADMacArchiveParser:XADArchiveParser
{
	CSHandle *dittohandle;
	XADRegex *dittoregex;
}

-(id)initWithHandle:(CSHandle *)handle name:(NSString *)name;
-(void)dealloc;

-(void)addEntryWithDictionary:(NSMutableDictionary *)dict retainPosition:(BOOL)retainpos;
-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum;

-(NSString *)nameForDittoFork:(NSString *)dict;
-(NSMutableDictionary *)parseAppleDoubleWithHandle:(CSHandle *)fh template:(NSDictionary *)template;

-(CSHandle *)rawHandleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum;

@end
