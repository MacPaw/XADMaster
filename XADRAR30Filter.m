#import "XADRAR30Filter.h"
#import "XADException.h"
#import "RARAudioDecoder.h"

@implementation XADRAR30Filter

+(XADRAR30Filter *)filterForProgramInvocation:(XADRARProgramInvocation *)program
startPosition:(off_t)startpos length:(int)length
{
	NSLog(@"%010qx",[[program programCode] fingerprint]);

	Class class;
	switch([[program programCode] fingerprint])
	{
		case 0x1d0e06077d: class=[XADRAR30DeltaFilter class]; break;
		case 0xd8bc85e701: class=[XADRAR30AudioFilter class]; break;
		default: class=[XADRAR30Filter class]; break;
	}

	return [[[class alloc] initWithProgramInvocation:program startPosition:startpos length:length] autorelease];
}

-(id)initWithProgramInvocation:(XADRARProgramInvocation *)program
startPosition:(off_t)startpos length:(int)length
{
	if(self=[super init])
	{
		invocation=[program retain];
		blockstartpos=startpos;
		blocklength=length;

		filteredblockaddress=filteredblocklength=0;
	}
	return self;
}

-(void)dealloc
{
	[invocation release];
	[super dealloc];
}

-(off_t)startPosition { return blockstartpos; }

-(int)length { return blocklength; }

-(uint32_t)filteredBlockAddress { return filteredblockaddress; }

-(uint32_t)filteredBlockLength { return filteredblocklength; }

-(void)executeOnVirtualMachine:(XADRARVirtualMachine *)vm atPosition:(off_t)pos
{
	[invocation restoreGlobalDataIfAvailable]; // This is silly, but RAR does it.

	[invocation setInitialRegisterState:6 toValue:(uint32_t)pos];
	[invocation setGlobalValueAtOffset:0x24 toValue:(uint32_t)pos];
	[invocation setGlobalValueAtOffset:0x28 toValue:(uint32_t)(pos>>32)];

	if(![invocation executeOnVitualMachine:vm]) [XADException raiseIllegalDataException];

	filteredblockaddress=[vm readWordAtAddress:RARProgramGlobalAddress+0x20]&RARProgramMemoryMask;
	filteredblocklength=[vm readWordAtAddress:RARProgramGlobalAddress+0x1c]&RARProgramMemoryMask;

	if(filteredblockaddress+filteredblocklength>=RARProgramMemorySize) filteredblockaddress=filteredblocklength=0;

	[invocation backupGlobalData]; // Also silly.
}

@end




@implementation XADRAR30DeltaFilter

-(void)executeOnVirtualMachine:(XADRARVirtualMachine *)vm atPosition:(off_t)pos
{
NSLog(@"delta");
	int length=[invocation initialRegisterState:4]; // should really be blocklength, but, RAR.
	int numchannels=[invocation initialRegisterState:0];
	uint8_t *memory=[vm memory];

	if(length>RARProgramWorkSize/2) return;

	filteredblockaddress=length;
	filteredblocklength=length;

	uint8_t *src=&memory[0];
	uint8_t *dest=&memory[filteredblockaddress];
	for(int i=0;i<numchannels;i++)
	{
		uint8_t lastbyte=0;
		for(int destoffs=i;destoffs<length;destoffs+=numchannels)
		{
			uint8_t newbyte=lastbyte-*src++;
			lastbyte=dest[destoffs]=newbyte;
		}
	}
}

@end



@implementation XADRAR30AudioFilter

-(void)executeOnVirtualMachine:(XADRARVirtualMachine *)vm atPosition:(off_t)pos
{
NSLog(@"audio");
	int length=[invocation initialRegisterState:4]; // should really be blocklength, but, RAR.
	int numchannels=[invocation initialRegisterState:0];
	uint8_t *memory=[vm memory];

	if(length>RARProgramWorkSize/2) return;

	filteredblockaddress=length;
	filteredblocklength=length;

	uint8_t *src=&memory[0];
	uint8_t *dest=&memory[filteredblockaddress];
	for(int i=0;i<numchannels;i++)
	{
		RAR30AudioState state;
		memset(&state,0,sizeof(state));

		for(int destoffs=i;destoffs<length;destoffs+=numchannels)
		{
			dest[destoffs]=DecodeRAR30Audio(&state,*src++);
		}
	}
}

@end
