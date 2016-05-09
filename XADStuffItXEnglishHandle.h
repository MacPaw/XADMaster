#import "CSByteStreamHandle.h"

@interface XADStuffItXEnglishHandle:CSByteStreamHandle
{
	uint8_t esccode,wordcode,firstcode,uppercode;
	BOOL caseflag;

	uint8_t wordbuf[33];
	int wordoffs,wordlen;
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length;

-(void)resetByteStream;
-(uint8_t)produceByteAtOffset:(off_t)pos;

@end
