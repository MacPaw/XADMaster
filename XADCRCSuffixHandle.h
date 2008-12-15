#import "CSStreamHandle.h"

@interface XADCRCSuffixHandle:CSStreamHandle
{
	CSHandle *parent,*crcparent;
	int crcsize;
	BOOL bigend;
	uint32_t crc,initcrc,compcrc;
	const uint32_t *table;
}

+(XADCRCHandle *)IEEECRC32SuffixHandleWithHandle:(CSHandle *)handle CRCHandle:(CSHandle *)crchandle
bigEndianCRC:(BOOL)bigendian conditioned:(BOOL)conditioned;
+(XADCRCHandle *)CCITTCRC16SuffixHandleWithHandle:(CSHandle *)handle CRCHandle:(CSHandle *)crchandle
bigEndianCRC:(BOOL)bigendian conditioned:(BOOL)conditioned;

-(id)initWithHandle:(CSHandle *)handle CRCHandle:(CSHandle *)crchandle initialCRC:(uint32_t)initialcrc
CRCSize:(int)crcbytes bigEndianCRC:(BOOL)bigendian CRCTable:(const uint32_t *)crctable;
-(void)dealloc;

-(void)resetStream;
-(int)streamAtMost:(int)num toBuffer:(void *)buffer;

-(BOOL)hasChecksum;
-(BOOL)isChecksumCorrect;

@end

