#import <Foundation/Foundation.h>

@class XADStringSource,UniversalDetector;

@interface XADString:NSObject
{
	NSData *data;
	NSString *string;
	XADStringSource *source;
}

+(XADString *)XADStringWithString:(NSString *)knownstring;

-(id)initWithData:(NSData *)bytedata source:(XADStringSource *)stringsource;
-(id)initWithString:(NSString *)knownstring;
-(void)dealloc;

-(NSString *)string;
-(NSString *)stringWithEncoding:(NSStringEncoding)encoding;
-(const char *)cString;

-(BOOL)encodingIsKnown;
-(float)confidence;

-(NSString *)description;

@end



@interface XADStringSource:NSObject
{
	UniversalDetector *detector;
	NSStringEncoding fixedencoding;
}

-(id)init;
-(void)dealloc;

-(XADString *)XADStringWithData:(NSData *)data;
-(XADString *)XADStringWithString:(NSString *)string;

-(NSStringEncoding)encoding;
-(float)confidence;
-(UniversalDetector *)detector;

-(void)setFixedEncoding:(NSStringEncoding)encoding;
-(BOOL)hasFixedEncoding;

@end
