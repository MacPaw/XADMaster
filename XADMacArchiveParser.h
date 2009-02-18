#import "XADArchiveParser.h"
#import "XADRegex.h"

extern NSString *XADIsMacBinaryKey;
extern NSString *XADMightBeMacBinaryKey;
extern NSString *XADDisableMacForkExpansionKey;

@interface XADMacArchiveParser:XADArchiveParser
{
	CSHandle *currhandle;
	XADRegex *dittoregex;
}

+(int)macBinaryVersionForHeader:(NSData *)header;

-(id)initWithHandle:(CSHandle *)handle name:(NSString *)name;
-(void)dealloc;

-(void)addEntryWithDictionary:(NSMutableDictionary *)dict retainPosition:(BOOL)retainpos;
-(BOOL)parseAppleDoubleWithDictionary:(NSMutableDictionary *)dict name:(NSString *)name;
-(BOOL)parseMacBinaryWithDictionary:(NSMutableDictionary *)dict name:(NSString *)name;

-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum;

-(CSHandle *)rawHandleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum;
-(void)inspectEntryDictionary:(NSMutableDictionary *)dict;

@end
