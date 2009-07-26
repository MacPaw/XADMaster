#import "XADArchiveParser.h"

@interface XADOldNSISParser:XADArchiveParser
{
	off_t base;
	uint32_t stringtable;
}

+(int)requiredHeaderSize;
+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name;

-(void)parse;

-(void)parseOlderFormat;
-(void)parseOldFormat;
-(void)parseNewishFormat;
-(void)parseOpcodesWithHeader:(NSData *)header strings:(NSDictionary *)strings blocks:(NSDictionary *)blocks
extractOpcode:(int)extractopcode directoryOpcode:(int)diropcode directoryArgument:(int)dirarg
startOffset:(int)startoffs endOffset:(int)endoffs stride:(int)stride;

-(NSDictionary *)findBlocksWithTotalSize:(uint32_t)totalsize;
-(NSDictionary *)findStringTableInData:(NSData *)data maxOffsets:(int)maxnumoffsets;
-(int)findOpcodeWithData:(NSData *)data strings:(NSDictionary *)strings blocks:(NSDictionary *)blocks
opcodePossibilities:(int *)possibleopcodes count:(int)numpossibleopcodes
stridePossibilities:(int *)possiblestrides count:(int)numpossiblestrides
foundStride:(int *)strideptr foundPhase:(int *)phaseptr;

-(XADPath *)cleanedPathForData:(NSData *)data;

-(CSHandle *)handleForBlockAtOffset:(off_t)offs;
-(CSHandle *)handleForBlockAtOffset:(off_t)offs length:(off_t)length;

-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum;
-(NSString *)formatName;

@end
