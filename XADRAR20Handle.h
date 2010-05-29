#import "XADFastLZSSHandle.h"
#import "XADRARParser.h"
#import "XADPrefixCode.h"

typedef struct XADRAR20AudioState
{
	int weight1,weight2,weight3,weight4,weight5;
	int delta1,delta2,delta3,delta4;
	int lastdelta;
	int error[11];
	int count;
	int lastbyte;
} XADRAR20AudioState;

@interface XADRAR20Handle:XADFastLZSSHandle
{
	XADRARParser *parser;

	NSArray *parts;
	int part;
	off_t endpos;

	XADPrefixCode *maincode,*offsetcode,*lengthcode;
	XADPrefixCode *audiocode[4];

	int lastoffset,lastlength;
	int oldoffset[4],oldoffsetindex;

	BOOL audioblock;
	int channel,channeldelta,numchannels;
	XADRAR20AudioState audiostate[4];

	int lengthtable[1028];
}

-(id)initWithRARParser:(XADRARParser *)parent parts:(NSArray *)partarray;
-(void)dealloc;

-(void)resetLZSSHandle;
-(void)startNextPart;
-(void)expandFromPosition:(off_t)pos;
-(void)allocAndParseCodes;

@end
