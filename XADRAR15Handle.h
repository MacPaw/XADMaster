#import "XADFastLZSSHandle.h"
#import "XADPrefixCode.h"

@interface XADRAR15Handle:XADFastLZSSHandle
{
//	XADPrefixCode *maincode,*offsetcode,*lengthcode;
}

-(id)initWithRARParser:(XADRARParser *)parent version:(int)version parts:(NSArray *)partarray;
-(void)dealloc;

-(void)resetLZSSHandle;

@end
