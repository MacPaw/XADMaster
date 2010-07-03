#import "XADString.h"

@implementation XADString (PlatformSpecific)

+(NSString *)stringForData:(NSData *)data encodingName:(NSString *)encoding
{
	CFStringRef str=CFStringCreateWithBytes(kCFAllocatorDefault,[data bytes],[data length],
	CFStringConvertIANACharSetNameToEncoding((CFStringRef)encoding),false);
	return [(id)str autorelease];
}

+(NSData *)dataForString:(NSString *)string encodingName:(NSString *)encoding
{
	int numchars=[string length];

	CFIndex numbytes;
	if(CFStringGetBytes((CFStringRef)string,CFRangeMake(0,numchars),
	CFStringConvertIANACharSetNameToEncoding((CFStringRef)encoding),0,false,
	NULL,0,&numbytes)!=numchars) return nil;

	uint8_t *bytes=malloc(numbytes);

	CFStringGetBytes((CFStringRef)string,CFRangeMake(0,numchars),
	CFStringConvertIANACharSetNameToEncoding((CFStringRef)encoding),0,false,
	bytes,numbytes,NULL);

	return [NSData dataWithBytesNoCopy:bytes length:numbytes freeWhenDone:YES];
}

+(NSArray *)availableEncodingNames
{
}

@end
