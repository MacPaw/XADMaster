#import "XADPPMdHandles.h"

@implementation XADPPMdVariantGHandle

-(id)initWithHandle:(CSHandle *)handle maxOrder:(int)maxorder subAllocSize:(int)suballocsize
{
	return [self initWithHandle:handle length:CSHandleMaxLength maxOrder:maxorder subAllocSize:suballocsize];
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length maxOrder:(int)maxorder subAllocSize:(int)suballocsize
{
	if(self=[super initWithHandle:handle length:length])
	{
		StartSubAllocator(&model.core.alloc,suballocsize);
		model.MaxOrder=maxorder;
	}
	return self;
}

-(void)dealloc
{
	StopSubAllocator(&model.core.alloc);
	[super dealloc];
}

-(void)resetByteStream { StartPPMdVariantGModel(&model,input); }

-(uint8_t)produceByteAtOffset:(off_t)pos
{
	int byte=NextPPMdVariantGByte(&model);
	if(byte<0) CSByteStreamEOF(self);
	return byte;
}

@end


@implementation XADPPMdVariantHHandle

-(id)initWithHandle:(CSHandle *)handle maxOrder:(int)maxorder subAllocSize:(int)suballocsize
{
	return [self initWithHandle:handle length:CSHandleMaxLength maxOrder:maxorder subAllocSize:suballocsize];
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length maxOrder:(int)maxorder subAllocSize:(int)suballocsize
{
	if(self=[super initWithHandle:handle length:length])
	{
		StartSubAllocator(&model.core.alloc,suballocsize);
		model.MaxOrder=maxorder;
	}
	return self;
}

-(void)dealloc
{
	StopSubAllocator(&model.core.alloc);
	[super dealloc];
}

-(void)resetByteStream { StartPPMdVariantHModel(&model,input,model.MaxOrder); }

-(uint8_t)produceByteAtOffset:(off_t)pos
{
	int byte=NextPPMdVariantHByte(&model);
	if(byte<0) CSByteStreamEOF(self);
	return byte;
}

@end
