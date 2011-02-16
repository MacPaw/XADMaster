#import "XADArchiveParser.h"

@interface XADISO9660Parser:XADArchiveParser
{
	off_t blocksize,blockoffset;
}

+(int)requiredHeaderSize;
+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data
name:(NSString *)name propertiesToAdd:(NSMutableDictionary *)props;

-(void)parse;
-(void)parseVolumeDescriptorAtBlock:(uint32_t)block isJoliet:(BOOL)isjoliet;
-(void)parseDirectoryWithPath:(XADPath *)path atBlock:(uint32_t)block
length:(uint32_t)length isJoliet:(BOOL)isjoliet;

-(XADString *)readStringOfLength:(int)length isJoliet:(BOOL)isjoliet;
-(NSDate *)readLongDateAndTime;
-(NSDate *)readShortDateAndTime;

-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum;
-(NSString *)formatName;

@end
