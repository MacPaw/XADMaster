#import "XADString.h"

#import <iconv.h>

@implementation XADString (PlatformSpecific)

+(NSString *)stringForData:(NSData *)data encodingName:(NSString *)encoding
{
	char encbuf[];
	IconvNameForEncodingName(encbuf,encoding);

	iconv_t ic=iconv_open("UCS-2-INTERNAL",encbuf);
	if(ic==(iconv_t)(-1)) return nil;


}

+(NSData *)dataForString:(NSString *)string encodingName:(NSString *)encoding
{
}

+(NSArray *)availableEncodingNames
{
}

@end
