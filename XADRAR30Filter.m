#import "XADRAR30Filter.h"
#import "XADException.h"

@implementation XADRAR30Filter

+(XADRAR30Filter *)filterForProgramInvocation:(XADRARProgramInvocation *)program
startPosition:(off_t)startpos length:(int)length
{
NSLog(@"%08x",[[program programCode] CRC]);

	Class class;
	switch([[program programCode] CRC])
	{
		case 0x0e06077d: class=[XADRAR30DeltaFilter class]; break;
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

	[invocation executeOnVitualMachine:vm];

	filteredblockaddress=XADRARVirtualMachineRead32(vm,XADRARProgramGlobalAddress+0x20)&XADRARProgramMemoryMask;
	filteredblocklength=XADRARVirtualMachineRead32(vm,XADRARProgramGlobalAddress+0x1c)&XADRARProgramMemoryMask;
filteredblockaddress=0;
filteredblocklength=[invocation initialRegisterState:4];

	if(filteredblockaddress+filteredblocklength>=XADRARProgramMemorySize) filteredblockaddress=filteredblocklength=0;

	[invocation backupGlobalData]; // Also silly.
}

@end


@implementation XADRAR30DeltaFilter

-(void)executeOnVirtualMachine:(XADRARVirtualMachine *)vm atPosition:(off_t)pos
{
	int length=[invocation initialRegisterState:4]; // should really be blocklength, but, RAR.
	int numchannels=[invocation initialRegisterState:0];
	uint8_t *memory=[vm memory];

	if(length>XADRARProgramWorkSize/2) return;

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
