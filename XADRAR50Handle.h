#import "CSBlockStreamHandle.h"
#import "XADRAR5Parser.h"
#import "LZSS.h"
#import "XADPrefixCode.h"
#import "PPMd/VariantH.h"
#import "PPMd/SubAllocatorVariantH.h"

@interface XADRAR50Handle:CSBlockStreamHandle
{
	XADRAR5Parser *parser;

	NSArray *files;
	int file;
	BOOL startnewfile;
	off_t currfilestartpos;

	off_t blockbitend;
	BOOL islastblock;

	LZSS lzss;

	XADPrefixCode *maincode,*offsetcode,*lowoffsetcode,*lengthcode;

	int lastlength;
	int oldoffset[4];
	int lastlowoffset,numlowoffsetrepeats;

	NSMutableArray *filters;
	NSMutableData *filterdata;

	int lengthtable[306+64+16+44];
}

-(id)initWithRARParser:(XADRAR5Parser *)parentparser files:(NSArray *)filearray;
-(void)dealloc;

-(void)resetBlockStream;
-(int)produceBlockAtOffset:(off_t)pos;
-(off_t)expandToPosition:(off_t)end;
-(void)readBlockHeader;
-(void)allocAndParseCodes;

@end
