#import "CSFilterHandle.h"

@interface XADZipCryptHandle:CSFilterHandle
{
	NSData *password,*header;
	uint8_t test;

	uint32_t key0,key1,key2;
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length password:(NSData *)passdata testByte:(uint8_t)testbyte;
-(void)dealloc;

-(void)resetFilter;
-(uint8_t)produceByteAtOffset:(off_t)pos;

@end
