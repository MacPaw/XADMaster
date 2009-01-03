#import "CSByteStreamHandle.h"
#import "PPMdVariantG.h"
#import "PPMdVariantH.h"

@interface XADPPMdVariantGHandle:CSByteStreamHandle
{
	PPMdVariantGModel model;
}

-(id)initWithHandle:(CSHandle *)handle maxOrder:(int)maxorder subAllocSize:(int)suballocsize;
-(id)initWithHandle:(CSHandle *)handle length:(off_t)length maxOrder:(int)maxorder subAllocSize:(int)suballocsize;
-(void)dealloc;

-(void)resetByteStream;
-(uint8_t)produceByteAtOffset:(off_t)pos;

@end

@interface XADPPMdVariantHHandle:CSByteStreamHandle
{
}

-(id)initWithHandle:(CSHandle *)handle maxOrder:(int)maxorder subAllocSize:(int)suballocsize;
-(id)initWithHandle:(CSHandle *)handle length:(off_t)length maxOrder:(int)maxorder subAllocSize:(int)suballocsize;
-(void)dealloc;

-(void)resetByteStream;
-(uint8_t)produceByteAtOffset:(off_t)pos;

@end
