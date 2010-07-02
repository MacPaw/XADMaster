#import "XADString.h"

#import "../UniversalDetector/UniversalDetector.h"



NSString *XADUTF8StringEncodingName=@"XADUTF8StringEncodingName";



@implementation XADString

+(XADString *)XADStringWithString:(NSString *)knownstring
{
	return [[[self alloc] initWithString:knownstring] autorelease];
}

-(id)initWithData:(NSData *)bytedata source:(XADStringSource *)stringsource
{
	// Make sure the detector sees the data, and decode it directly if it is just ASCII
	if([stringsource analyzeDataAndCheckForASCII:bytedata])
	return [self initWithString:[[[NSString alloc] initWithData:bytedata encoding:NSASCIIStringEncoding] autorelease]];

	if(self=[super init])
	{
		data=[bytedata retain];
		string=nil;
		source=[stringsource retain];
	}
	return self;
}

-(id)initWithData:(NSData *)bytedata encodingName:(NSString *)encoding
{
	if(self=[super init])
	{
		// TODO: handle decoding failures
		string=[XADString stringForData:bytedata encodingName:encoding];
		data=nil;
		source=nil;
	}
	return self;
}

-(id)initWithString:(NSString *)knownstring
{
	if(self=[super init])
	{
		string=[knownstring retain];
		data=nil;
		source=nil;
	}
	return self;
}

-(void)dealloc
{
	[data release];
	[string release];
	[source release];
	[super dealloc];
}



-(NSString *)string
{
	return [self stringWithEncodingName:[source encodingName]];
}

-(NSString *)stringWithEncodingName:(NSString *)encoding
{
	if(string) return string;

	NSString *decstr=[XADString stringForData:data encodingName:encoding];
	if(decstr) return decstr;

	// Fall back on escaped ASCII if the encoding was unusable
	const uint8_t *bytes=[data bytes];
	int length=[data length];
	NSMutableString *str=[NSMutableString stringWithCapacity:length];

	for(int i=0;i<length;i++)
	{
		if(bytes[i]<0x80) [str appendFormat:@"%c",bytes[i]];
		else [str appendFormat:@"%%%02x",bytes[i]];
	}

	return [NSString stringWithString:str];
}

-(NSData *)data
{
	if(data) return data;

	int length=[string length];
	NSMutableData *encdata=[NSMutableData dataWithCapacity:length];

	for(int i=0;i<length;i++)
	{
		char bytes[8];
		unichar c=[string characterAtIndex:i];
		if(c<0x80)
		{
			bytes[0]=c;
			[encdata appendBytes:bytes length:1];
		}
		else
		{
			sprintf(bytes,"%%u%04x",c&0xffff);
			[encdata appendBytes:bytes length:6];
		}
	}

	return [NSData dataWithData:encdata];

	// Do not use this because Cocotron doesn't support it.
	//return [string dataUsingEncoding:NSNonLossyASCIIStringEncoding];
}



-(BOOL)encodingIsKnown
{
	if(!source) return YES;
	if([source hasFixedEncoding]) return YES;
	return NO;
}

-(NSString *)encodingName
{
	if(!source) return XADUTF8StringEncodingName; // TODO: what should this really return?
	return [source encodingName];
}

-(float)confidence
{
	if(!source) return 1;
	return [source confidence];
}



-(XADStringSource *)source { return source; }



-(BOOL)hasASCIIPrefix:(NSString *)asciiprefix
{
	if(string) return [string hasPrefix:asciiprefix];
	else
	{
		int length=[asciiprefix length];
		if([data length]<length) return NO;

		const uint8_t *bytes=[data bytes];
		for(int i=0;i<length;i++) if(bytes[i]!=[asciiprefix characterAtIndex:i]) return NO;

		return YES;
	}
}

-(XADString *)XADStringByStrippingASCIIPrefixOfLength:(int)length
{
	if(string)
	{
		return [[[XADString alloc]
		initWithString:[string substringFromIndex:length]]
		autorelease];
	}
	else
	{
		return [[[XADString alloc]
		initWithData:[data subdataWithRange:
		NSMakeRange(length,[data length]-length)]
		source:source] autorelease];
	}
}



-(BOOL)isEqual:(id)other
{
	if([other isKindOfClass:[NSString class]]) return [[self string] isEqual:other];
	else if([other isKindOfClass:[self class]])
	{
		XADString *xadstr=(XADString *)other;

		if(string&&xadstr->string) return [string isEqual:xadstr->string];
		else if(data&&xadstr->data&&source==xadstr->source) return [data isEqual:xadstr->data];
		else return NO;
	}
	else return NO;
}

-(NSUInteger)hash
{
	if(string) return [string hash];
	else return [data hash];
}



-(NSString *)description
{
	// TODO: more info?
	return [self string];
}

-(id)copyWithZone:(NSZone *)zone
{
	if(string) return [[XADString allocWithZone:zone] initWithString:string];
	else return [[XADString allocWithZone:zone] initWithData:data source:source];
}


#ifdef __APPLE__
-(NSString *)stringWithEncoding:(NSStringEncoding)encoding
{
	return [self stringWithEncodingName:(NSString *)CFStringConvertEncodingToIANACharSetName(
	CFStringConvertNSStringEncodingToEncoding(encoding))];
}

-(NSStringEncoding)encoding
{
	if(!source) return NSUTF8StringEncoding; // TODO: what should this really return?
	return [source encoding];
}
#endif

@end



@implementation XADStringSource

-(id)init
{
	if(self=[super init])
	{
		detector=[UniversalDetector new]; // can return nil if UniversalDetector is not found
		fixedencodingname=nil;
//		fixedencoding=0;
		mac=NO;
	}
	return self;
}

-(void)dealloc
{
	[detector release];
	[fixedencodingname release];
	[super dealloc];
}

-(BOOL)analyzeDataAndCheckForASCII:(NSData *)data
{
	[detector analyzeData:data];

	// check if string is ASCII
	const char *ptr=[data bytes];
	int length=[data length];
	for(int i=0;i<length;i++) if(ptr[i]&0x80) return NO;

	return YES;
}

-(NSString *)encodingName
{
	if(fixedencodingname) return fixedencodingname;
//	if(!detector) return NSWindowsCP1252StringEncoding;

	NSString *encoding=[detector MIMECharset];
//	if(!encoding) encoding=NSWindowsCP1252StringEncoding;

	// Kludge to use Mac encodings instead of the similar Windows encodings for Mac archives
	// TODO: improve
/*	#ifdef __APPLE__
	if(mac)
	{
		if(encoding==NSWindowsCP1252StringEncoding) return NSMacOSRomanStringEncoding;

		NSStringEncoding macjapanese=CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingMacJapanese);
		if(encoding==NSShiftJISStringEncoding) return macjapanese;
		//else if(encoding!=NSUTF8StringEncoding&&encoding!=macjapanese) encoding=NSMacOSRomanStringEncoding;
	}
	#endif*/

	return encoding;
}

-(float)confidence
{
	if(fixedencodingname) return 1;
	if(!detector) return 0;
	if(![detector MIMECharset]) return 0;
	return [detector confidence];
}

-(UniversalDetector *)detector
{
	return detector;
}

-(void)setFixedEncodingName:(NSString *)encoding
{
	[fixedencodingname autorelease];
	fixedencodingname=[encoding retain];
}

-(BOOL)hasFixedEncoding
{
	return fixedencodingname!=nil;
}

-(void)setPrefersMacEncodings:(BOOL)prefermac
{
	mac=prefermac;
}



#ifdef __APPLE__
-(NSStringEncoding)encoding
{
	NSString *encodingname=[self encodingName];
	if(!encodingname) return 0;

	CFStringEncoding cfenc=CFStringConvertIANACharSetNameToEncoding((CFStringRef)encodingname);
	if(cfenc==kCFStringEncodingInvalidId) return 0;

	return CFStringConvertEncodingToNSStringEncoding(cfenc);
}

-(void)setFixedEncoding:(NSStringEncoding)encoding
{
	[self setFixedEncodingName:(NSString *)CFStringConvertEncodingToIANACharSetName(encoding)];
}
#endif

@end
