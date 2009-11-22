#import "XADLZSSHandle.h"

@interface XADQuantumHandle:XADLZSSHandle
{
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length;
-(void)dealloc;

-(void)resetLZSSHandle;
-(int)nextLiteralOrOffset:(int *)offset andLength:(int *)length atPosition:(off_t)pos;

@end
