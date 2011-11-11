#import "XADArchiveParser.h"
#import "CSStreamHandle.h"

extern NSString *XADIsMacBinaryKey;
extern NSString *XADMightBeMacBinaryKey;
extern NSString *XADDisableMacForkExpansionKey;

@interface XADMacArchiveParser:XADArchiveParser
{
	XADPath *previousname;
	NSMutableArray *dittodirectorystack;

	NSMutableDictionary *queueddittoentry;
	NSData *queueddittodata;

	NSMutableDictionary *cachedentry;
	NSData *cacheddata;
	CSHandle *cachedhandle;
}

+(int)macBinaryVersionForHeader:(NSData *)header;

-(id)initWithHandle:(CSHandle *)handle name:(NSString *)name;
-(void)dealloc;

-(void)parse;
-(void)parseWithSeparateMacForks;

-(void)addEntryWithDictionary:(NSMutableDictionary *)dict retainPosition:(BOOL)retainpos cyclePools:(BOOL)cyclepools;

-(BOOL)parseAppleDoubleWithDictionary:(NSMutableDictionary *)dict name:(XADPath *)name
retainPosition:(BOOL)retainpos cyclePools:(BOOL)cyclepools;

-(void)setPreviousFilename:(XADPath *)prevname;
-(XADPath *)topOfDittoDirectoryStack;
-(void)pushDittoDirectory:(XADPath *)directory;
-(void)popDittoDirectoryStackUntilCanonicalPrefixFor:(XADPath *)path;

-(void)queueDittoDictionary:(NSMutableDictionary *)dict data:(NSData *)data;
-(void)addQueuedDittoDictionaryAndRetainPosition:(BOOL)retainpos;
-(void)addQueuedDittoDictionaryWithName:(XADPath *)newname
isDirectory:(BOOL)isdir retainPosition:(BOOL)retainpos;

-(BOOL)parseMacBinaryWithDictionary:(NSMutableDictionary *)dict name:(XADPath *)name
retainPosition:(BOOL)retainpos cyclePools:(BOOL)cyclepools;

-(void)addEntryWithDictionary:(NSMutableDictionary *)dict retainPosition:(BOOL)retainpos
cyclePools:(BOOL)cyclepools data:(NSData *)data;
-(void)addEntryWithDictionary:(NSMutableDictionary *)dict retainPosition:(BOOL)retainpos
cyclePools:(BOOL)cyclepools handle:(CSHandle *)handle;

-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum;

-(CSHandle *)rawHandleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum;
-(void)inspectEntryDictionary:(NSMutableDictionary *)dict;

@end
