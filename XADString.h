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
-(NSStringEncoding)encoding;
-(float)confidence;
-(NSData *)data;

-(BOOL)isEqual:(XADString *)other;
-(unsigned)hash;
-(id)copyWithZone:(NSZone *)zone;

@end



@interface XADStringSource:NSObject
{
	UniversalDetector *detector;
	NSStringEncoding fixedencoding;
	BOOL mac;
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
-(void)setPrefersMacEncodings:(BOOL)prefermac;

@end
