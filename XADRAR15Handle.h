#import "XADRARHandle.h"
#import "XADPrefixCode.h"

@interface XADRAR15Handle:XADRARHandle
{
//	XADPrefixCode *maincode,*offsetcode,*lengthcode;
}

-(id)initWithRARParser:(XADRARParser *)parent version:(int)version parts:(NSArray *)partarray;
-(void)dealloc;

-(void)resetLZSSHandle;
-(int)nextLiteralOrOffset:(int *)offset andLength:(int *)length atPosition:(off_t)pos;
//-(void)allocAndParseCodes;

@end
