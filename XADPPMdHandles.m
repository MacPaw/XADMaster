#import "XADPPMdHandles.h"
#import "PPMdSubAllocatorVariantG.h"
#import "PPMdSubAllocatorVariantH.h"
#import "PPMdSubAllocatorVariantI.h"

@implementation XADPPMdVariantGHandle

-(id)initWithHandle:(CSHandle *)handle maxOrder:(int)maxorder subAllocSize:(int)suballocsize
{
	return [self initWithHandle:handle length:CSHandleMaxLength maxOrder:maxorder subAllocSize:suballocsize];
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length maxOrder:(int)maxorder subAllocSize:(int)suballocsize
{
	if(self=[super initWithHandle:handle length:length])
	{
		model.core.alloc=&CreateSubAllocatorVariantG(suballocsize)->core;
		model.MaxOrder=maxorder;
	}
	return self;
}

-(void)dealloc
{
	FreeSubAllocatorVariantG((PPMdSubAllocatorVariantG *)model.core.alloc);
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
		model.core.alloc=&CreateSubAllocatorVariantH(suballocsize)->core;
		model.MaxOrder=maxorder;
	}
	return self;
}

-(void)dealloc
{
	FreeSubAllocatorVariantH((PPMdSubAllocatorVariantH *)model.core.alloc);
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




@implementation XADPPMdVariantIHandle

-(id)initWithHandle:(CSHandle *)handle maxOrder:(int)maxorder subAllocSize:(int)suballocsize modelRestorationMethod:(int)mrmethod
{
	return [self initWithHandle:handle length:CSHandleMaxLength maxOrder:maxorder subAllocSize:suballocsize modelRestorationMethod:mrmethod];
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length maxOrder:(int)maxorder subAllocSize:(int)suballocsize modelRestorationMethod:(int)mrmethod
{
	if(self=[super initWithHandle:handle length:length])
	{
		model.core.alloc=&CreateSubAllocatorVariantI(suballocsize)->core;
		model.MaxOrder=maxorder;
		model.MRMethod=mrmethod;
	}
	return self;
}

-(void)dealloc
{
	FreeSubAllocatorVariantI((PPMdSubAllocatorVariantI *)model.core.alloc);
	[super dealloc];
}

-(void)resetByteStream { StartPPMdVariantIModel(&model,input,model.MaxOrder,model.MRMethod); }

-(uint8_t)produceByteAtOffset:(off_t)pos
{
	int byte=NextPPMdVariantIByte(&model);
	if(byte<0) CSByteStreamEOF(self);
	return byte;
}

@end
