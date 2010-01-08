#import "CSBlockStreamHandle.h"
#import "XADPrefixCode.h"

@interface XADDiskDoublerDDnHandle:CSBlockStreamHandle
{
	uint8_t outbuffer[0x1010e];
	BOOL checksumcorrect;
}

-(void)resetBlockStream;
-(int)produceBlockAtOffset:(off_t)pos;
-(XADPrefixCode *)readCode;

-(BOOL)hasChecksum;
-(BOOL)isChecksumCorrect;

@end

/*
#import "XADLZSSHandle.h"
#import "XADPrefixCode.h"

@interface XADDiskDoublerDDnHandle:XADLZSSHandle
{
	off_t blockend;
	int literalsleft;

	uint8_t buffer[0x10000];
	uint8_t *literalptr;
	uint16_t *offsetptr;

	BOOL checksumcorrect;
}

-(void)resetLZSSStream;
-(int)nextLiteralOrOffset:(int *)offset andLength:(int *)length atPosition:(off_t)pos;

-(XADPrefixCode *)readCode;

-(BOOL)hasChecksum;
-(BOOL)isChecksumCorrect;

@end
*/