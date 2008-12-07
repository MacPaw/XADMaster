#import "XADString.h"

#import <UniversalDetector/UniversalDetector.h>



@implementation XADString

+(XADString *)XADStringWithString:(NSString *)knownstring
{
	return [[[self alloc] initWithString:knownstring] autorelease];
}

-(id)initWithData:(NSData *)bytedata source:(XADStringSource *)stringsource
{
	if(self=[super init])
	{
		data=[bytedata retain];
		string=nil;
		source=[stringsource retain];
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
	if(string) return string;
	return [[[NSString alloc] initWithData:data encoding:[source encoding]] autorelease];
}

-(NSString *)stringWithEncoding:(NSStringEncoding)encoding
{
	if(string) return string;
	return [[[NSString alloc] initWithData:data encoding:encoding] autorelease];
}

-(const char *)cString
{
	if(string) return NULL;

	NSMutableData *mutable=[NSMutableData dataWithData:data];
	[mutable increaseLengthBy:1]; // add a single byte, which will be initialized as 0
	return [mutable bytes];
}

-(BOOL)encodingIsKnown
{
	if(string) return YES;
	if([source hasFixedEncoding]) return YES;
	return NO;
}

-(float)confidence
{
	if(string) return 1;
	return [source confidence];
}

-(NSString *)description
{
	// TODO: more info?
	NSString *str=[self string];
	if(str) return str;
	else return [data description];
}

@end



@implementation XADStringSource

-(id)init
{
	if(self=[super init])
	{
		detector=[UniversalDetector new]; // can return nil if UniversalDetector is not found
		fixedencoding=0;
	}
	return self;
}

-(void)dealloc
{
	[detector release];
	[super dealloc];
}

-(XADString *)XADStringWithData:(NSData *)data
{
	[detector analyzeData:data];

	// check if string is ASCII, and convert it directly to an NSString if it is
	const char *ptr=[data bytes];
	int length=[data length];
	for(int i=0;i<length;i++) if(ptr[i]<0x20||ptr[i]>=0x80)
	return [[[XADString alloc] initWithData:data source:self] autorelease];

	return [[[XADString alloc] initWithString:[[[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding] autorelease]] autorelease];
}

-(XADString *)XADStringWithString:(NSString *)string
{
	return [[[XADString alloc] initWithString:string] autorelease];
}

-(NSStringEncoding)encoding
{
	if(fixedencoding) return fixedencoding;
	if(!detector) return NSWindowsCP1252StringEncoding;
	NSStringEncoding encoding=[detector encoding];
	if(!encoding) return NSWindowsCP1252StringEncoding;

	// TODO:
/*		// Kludge to use Mac encodings instead of the similar Windows encodings for Mac archives
		if(info->xfi_Flags&(XADFIF_MACDATA|XADFIF_MACRESOURCE))
		{
			NSStringEncoding macjapanese=CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingMacJapanese);
			if(encoding==NSShiftJISStringEncoding) encoding=macjapanese;
			//else if(encoding!=NSUTF8StringEncoding&&encoding!=macjapanese) encoding=NSMacOSRomanStringEncoding;
		}
*/


	return encoding;
}

-(float)confidence
{
	if(fixedencoding) return 1;
	if(!detector) return 0;
	NSStringEncoding encoding=[detector encoding];
	if(!encoding) return 0;
	return [detector confidence];
}

-(UniversalDetector *)detector
{
	return detector;
}

-(void)setFixedEncoding:(NSStringEncoding)encoding
{
	fixedencoding=encoding;
}

-(BOOL)hasFixedEncoding
{
	return fixedencoding!=0;
}

@end
