#import "XADArchiveParser.h"
#import "XADRegex.h"

extern NSString *XADIsMacBinaryKey;
extern NSString *XADDisableMacForkExpansionKey;

@interface XADMacArchiveParser:XADArchiveParser
{
	CSHandle *currhandle;
	XADRegex *dittoregex;
}

-(id)initWithHandle:(CSHandle *)handle name:(NSString *)name;
-(void)dealloc;

-(void)addEntryWithDictionary:(NSMutableDictionary *)dict retainPosition:(BOOL)retainpos;
-(void)addEntryWithDictionary:(NSMutableDictionary *)dict checkForMacBinary:(BOOL)checkbin;
-(void)addEntryWithDictionary:(NSMutableDictionary *)dict retainPosition:(BOOL)retainpos checkForMacBinary:(BOOL)checkbin;
-(BOOL)parseAppleDoubleWithDictionary:(NSMutableDictionary *)dict name:(NSString *)name;
-(BOOL)parseMacBinaryWithDictionary:(NSMutableDictionary *)dict name:(NSString *)name checkContents:(BOOL)check;

-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum;

-(CSHandle *)rawHandleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum;
-(void)inspectEntryDictionary:(NSMutableDictionary *)dict;

@end
