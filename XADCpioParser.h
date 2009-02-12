#import "XADMacArchiveParser.h"
#import "CSStreamHandle.h"

@interface XADCpioParser:XADMacArchiveParser
{
}

+(int)requiredHeaderSize;
+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name;

-(void)parse;
-(CSHandle *)rawHandleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum;
-(NSString *)formatName;

@end

@interface XADCpioChecksumHandle:CSStreamHandle
{
	CSHandle *parent;
	int correctchecksum,checksum;
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length correctChecksum:(int)correct;
-(void)dealloc;

-(void)resetStream;
-(int)streamAtMost:(int)num toBuffer:(void *)buffer;

-(BOOL)hasChecksum;
-(BOOL)isChecksumCorrect;

@end


