#import "XADRARHandle.h"
#import "XADPrefixCode.h"
#import "PPMdVariantH.h"
#import "PPMdSubAllocatorVariantH.h"
#import "XADRARVirtualMachine.h"

@interface XADRAR30Handle:XADRARHandle
{
	int lengthtable[299+60+17+28];

	XADPrefixCode *maincode,*offsetcode,*lowoffsetcode,*lengthcode;

	int lastoffset,lastlength;
	int oldoffset[4];
	int lastlowoffset,numlowoffsetrepeats;

	BOOL ppmblock;
	PPMdModelVariantH ppmd;
	PPMdSubAllocatorVariantH *alloc;
	int ppmescape;

	NSMutableArray *filtercode,*stack;
	int lastfilternum;
	int oldfilterlength[1024],usagecount[1024];
	off_t filterend;
}

-(id)initWithRARParser:(XADRARParser *)parent version:(int)version parts:(NSArray *)partarray;
-(void)dealloc;

-(void)resetLZSSHandle;
-(void)expandFromPosition:(off_t)pos;
-(void)allocAndParseCodes;

-(void)readFilterFromInputAtPosition:(off_t)pos;
-(void)readFilterFromPPMdAtPosition:(off_t)pos;
-(void)parseFilter:(const uint8_t *)bytes length:(int)length flags:(int)flags position:(off_t)pos;

@end

@interface XADRAR30Filter:NSObject
{
	XADRARProgramInvocation *invocation;
	off_t startpos;
	int length;
}

-(id)initWithProgramInvocation:(XADRARProgramInvocation *)program
startPosition:(off_t)blockstart length:(int)blocklength;
-(void)dealloc;

-(off_t)startPosition;
-(int)length;

-(void)executeOnVirtualMachine:(XADRARVirtualMachine *)vm atPosition:(off_t)pos;

@end
