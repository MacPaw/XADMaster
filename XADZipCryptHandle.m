#import "XADZipCryptHandle.h"
#import "XADChecksums.h"
#import "XADException.h"

@implementation XADZipCryptHandle

static void UpdateKeys(XADZipCryptHandle *self,uint8_t b)
{
	self->key0=XADCRC32(self->key0,b,XADCRC32Table_edb88320);
	self->key1+=self->key0&0xff;
	self->key1=self->key1*134775813+1;
	self->key2=XADCRC32(self->key2,self->key1>>24,XADCRC32Table_edb88320);
}

static uint8_t DecryptByte(XADZipCryptHandle *self)
{
	uint16_t temp=self->key2|2;
	return (temp*(temp^1))>>8;
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length password:(NSData *)passdata testByte:(uint8_t)testbyte
{
	NSData *headerdata=[handle readDataOfLength:12];
	if(self=[super initWithHandle:handle length:length-12])
	{
		header=[headerdata retain];
		password=[passdata retain];
		test=testbyte;
	}
	return self;
}

-(void)dealloc
{
	[header release];
	[password release];
	[super dealloc];
}



-(void)resetFilter
{
	key0=305419896;
	key1=591751049;
	key2=878082192;

	int passlength=[password length];
	const uint8_t *passbytes=[password bytes];
	for(int i=0;i<passlength;i++) UpdateKeys(self,passbytes[i]);

	const uint8_t *headbytes=[header bytes];
	for(int i=0;i<12;i++)
	{
		uint8_t b=headbytes[i]^DecryptByte(self);
		UpdateKeys(self,b);
		if(i==11&&b!=test) [XADException raisePasswordException];
	}
}

-(uint8_t)produceByteAtOffset:(off_t)pos
{
	uint8_t b=CSFilterNextByte(self)^DecryptByte(self);
//NSLog(@"%02x",b);
	UpdateKeys(self,b);
	return b;
}

@end
