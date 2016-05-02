#import "XADRARFilters.h"
#import "XADException.h"
#import "RARAudioDecoder.h"

static void RARDeltaFilter(uint8_t *src,uint8_t *dest,size_t length,int numchannels);
static void RARE8E9Filter(uint8_t *memory,size_t length,off_t filepos,bool handlee9,bool wrapposition);
static void RARARMFilter(uint8_t *memory,size_t length,off_t filepos);

@implementation XADRAR30Filter

+(XADRAR30Filter *)filterForProgramInvocation:(XADRARProgramInvocation *)program
startPosition:(off_t)startpos length:(int)length
{
	//NSLog(@"%010qx",[[program programCode] fingerprint]);

	Class class;
	switch([[program programCode] fingerprint])
	{
		case 0x1d0e06077d: class=[XADRAR30DeltaFilter class]; break;
		case 0xd8bc85e701: class=[XADRAR30AudioFilter class]; break;
		case 0x35ad576887: class=[XADRAR30E8Filter class]; break;
		case 0x393cd7e57e: class=[XADRAR30E8E9Filter class]; break;
		default: class=[XADRAR30Filter class]; break;
	}

	return [[[class alloc] initWithProgramInvocation:program startPosition:startpos length:length] autorelease];
}

-(id)initWithProgramInvocation:(XADRARProgramInvocation *)program
startPosition:(off_t)startpos length:(int)length
{
	if((self=[super init]))
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

	filteredblockaddress=[vm readWordAtAddress:RARProgramSystemGlobalAddress+0x20]&RARProgramMemoryMask;
	filteredblocklength=[vm readWordAtAddress:RARProgramSystemGlobalAddress+0x1c]&RARProgramMemoryMask;

	if(filteredblockaddress+filteredblocklength>=RARProgramMemorySize) filteredblockaddress=filteredblocklength=0;

	[invocation backupGlobalData]; // Also silly.
}

@end




@implementation XADRAR30DeltaFilter

-(void)executeOnVirtualMachine:(XADRARVirtualMachine *)vm atPosition:(off_t)pos
{
	int length=[invocation initialRegisterState:4]; // should really be blocklength, but, RAR.
	int numchannels=[invocation initialRegisterState:0];
	uint8_t *memory=[vm memory];

	if(length>RARProgramWorkSize/2) return;

	filteredblockaddress=length;
	filteredblocklength=length;

	uint8_t *src=&memory[0];
	uint8_t *dest=&memory[filteredblockaddress];

	RARDeltaFilter(src,dest,length,numchannels);
}

@end



@implementation XADRAR30AudioFilter

-(void)executeOnVirtualMachine:(XADRARVirtualMachine *)vm atPosition:(off_t)pos
{
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



@implementation XADRAR30E8Filter

-(void)executeOnVirtualMachine:(XADRARVirtualMachine *)vm atPosition:(off_t)pos
{
	int length=[invocation initialRegisterState:4];
	uint8_t *memory=[vm memory];

	if(length>RARProgramWorkSize || length<4) return;

	filteredblockaddress=0;
	filteredblocklength=length;

	RARE8E9Filter(memory,length,pos,false,false);
}

@end



@implementation XADRAR30E8E9Filter

-(void)executeOnVirtualMachine:(XADRARVirtualMachine *)vm atPosition:(off_t)pos
{
	int length=[invocation initialRegisterState:4];
	uint8_t *memory=[vm memory];

	if(length>RARProgramWorkSize || length<4) return;

	filteredblockaddress=0;
	filteredblocklength=length;

	RARE8E9Filter(memory,length,pos,true,false);
}

@end






@implementation XADRAR50Filter

-(id)initWithStart:(off_t)filterstart length:(uint32_t)filterlength
{
	if(self=[super init])
	{
		start=filterstart;
		length=filterlength;
	}
	return self;
}

-(off_t)start { return start; }

-(uint32_t)length { return length; }

-(void)runOnData:(NSMutableData *)data fileOffset:(off_t)pos { }

@end




@implementation XADRAR50DeltaFilter

-(id)initWithStart:(off_t)filterstart length:(uint32_t)filterlength numberOfChannels:(int)numberofchannels
{
	if(self=[super initWithStart:filterstart length:filterlength])
	{
		numchannels=numberofchannels;
	}
	return self;
}

-(void)runOnData:(NSMutableData *)data fileOffset:(off_t)pos
{
	uint8_t *memory=[data mutableBytes];
	size_t memlength=[data length];

	NSMutableData *destdata=[[NSMutableData alloc] initWithLength:memlength];
	uint8_t *destmem=[destdata mutableBytes];

	RARDeltaFilter(memory,destmem,memlength,numchannels);

	memcpy(memory,destmem,memlength);

	[destdata release];
}

@end




@implementation XADRAR50E8E9Filter

-(id)initWithStart:(off_t)filterstart length:(uint32_t)filterlength handleE9:(BOOL)shouldhandlee9
{
	if(self=[super initWithStart:filterstart length:filterlength])
	{
		handlee9=shouldhandlee9;
	}
	return self;
}

-(void)runOnData:(NSMutableData *)data fileOffset:(off_t)pos
{
	uint8_t *memory=data.mutableBytes;
	size_t memlength=data.length;

	RARE8E9Filter(memory,memlength,pos,handlee9,true);
}

@end




@implementation XADRAR50ARMFilter

-(void)runOnData:(NSMutableData *)data fileOffset:(off_t)pos
{
	uint8_t *memory=data.mutableBytes;
	size_t memlength=data.length;

	RARARMFilter(memory,memlength,pos);
}

@end




static void RARDeltaFilter(uint8_t *src,uint8_t *dest,size_t length,int numchannels)
{
	for(int i=0;i<numchannels;i++)
	{
		uint8_t lastbyte=0;
		for(int destoffs=i;destoffs<length;destoffs+=numchannels)
		{
			uint8_t newbyte=lastbyte-*src++;
			dest[destoffs]=newbyte;
			lastbyte=newbyte;
		}
	}
}

static void RARE8E9Filter(uint8_t *memory,size_t length,off_t filepos,bool handlee9,bool wrapposition)
{
	int32_t filesize=0x1000000;

	for(size_t i=0;i<=length-5;i++)
	{
		if(memory[i]==0xe8 || (handlee9 && memory[i]==0xe9))
		{
			int32_t currpos=(int32_t)filepos+i+1;
			if(wrapposition) currpos%=filesize;
 			int32_t address=CSInt32LE(&memory[i+1]);
			if(address<0)
			{
				if(address+currpos>=0) CSSetUInt32LE(&memory[i+1],address+filesize);
			}
            else
			{
				if(address<filesize) CSSetUInt32LE(&memory[i+1],address-currpos);
			}

			i+=4;
		}
	}
}

static void RARARMFilter(uint8_t *memory,size_t length,off_t filepos)
{
	for(size_t i=0;i<=length-4;i+=4)
	{
		if(memory[i+3]==0xeb)
		{
			uint32_t offset=memory[i]+(memory[i+1]<<8)+(memory[i+2]<<16);
			offset-=((uint32_t)filepos+i)/4;
			memory[i]=offset;
			memory[i+1]=offset>>8;
			memory[i+2]=offset>>16;
		}
	}
}
