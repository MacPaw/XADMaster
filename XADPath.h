#import "XADString.h"

#define XADUnixPathSeparator "/"
#define XADWindowsPathSeparator "\\"
#define XADEitherPathSeparator "/\\"
#define XADNoPathSeparator ""

@interface XADPath:NSObject <XADString>
{
	NSArray *components;
	XADStringSource *source;
}

-(id)init;
-(id)initWithComponents:(NSArray *)pathcomponents;
-(id)initWithString:(NSString *)pathstring;
-(id)initWithBytes:(const char *)bytes length:(int)length
encodingName:(NSString *)encoding separators:(const char *)separators;
-(id)initWithBytes:(const char *)bytes length:(int)length
separators:(const char *)separators source:(XADStringSource *)stringsource;
-(id)initWithBytes:(const char *)bytes length:(int)length encodingName:(NSString *)encoding
separators:(const char *)separators source:(XADStringSource *)stringsource;

-(void)dealloc;

-(XADString *)lastPathComponent;
-(XADString *)firstPathComponent;

-(XADPath *)pathByDeletingLastPathComponent;
-(XADPath *)pathByDeletingFirstPathComponent;
-(XADPath *)pathByAppendingPathComponent:(XADString *)component;
-(XADPath *)pathByAppendingPath:(XADPath *)path;
-(XADPath *)safePath; // Deprecated. Use sanitizedPathString: instead.

-(BOOL)isAbsolute;
-(BOOL)isEmpty;
-(BOOL)hasPrefix:(XADPath *)other;

// NOTE: These are not guaranteed to be safe for usage as filesystem paths,
// only for display!
-(NSString *)string;
-(NSString *)stringWithEncodingName:(NSString *)encoding;
-(NSData *)data;

// These are safe for filesystem use, and adapted to the current platform.
-(NSString *)sanitizedPathString;
-(NSString *)sanitizedPathStringWithEncodingName:(NSString *)encoding;

-(int)depth;
-(NSArray *)pathComponents;

-(BOOL)encodingIsKnown;
-(NSString *)encodingName;
-(float)confidence;

-(XADStringSource *)source;

-(BOOL)isEqual:(id)other;
-(NSUInteger)hash;
-(id)copyWithZone:(NSZone *)zone;

#ifdef __APPLE__
-(NSString *)stringWithEncoding:(NSStringEncoding)encoding;
-(NSString *)sanitizedPathStringWithEncoding:(NSStringEncoding)encoding;
-(NSStringEncoding)encoding;
#endif

@end
