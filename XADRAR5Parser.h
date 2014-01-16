#import "XADArchiveParser.h"

@interface XADRAR5Parser:XADArchiveParser
{
	NSData *headersalt;
}

+(int)requiredHeaderSize;
+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name;
+(NSArray *)volumesForHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name;

-(void)setPassword:(NSString *)newpassword;

-(void)parse;

//-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum;
//-(CSHandle *)handleForSolidStreamWithObject:(id)obj wantChecksum:(BOOL)checksum;

-(NSString *)formatName;

@end

@interface XADEmbeddedRAR5Parser:XADRAR5Parser
{
}

/*+(int)requiredHeaderSize;
+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data
name:(NSString *)name propertiesToAdd:(NSMutableDictionary *)props;

-(void)parse;
-(NSString *)formatName;*/

@end

