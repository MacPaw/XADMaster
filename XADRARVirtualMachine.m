#import "XADRARVirtualMachine.h"
#import "XADException.h"
#import "CRC.h"

#define RARMovOpcode 0
#define RARCmpOpcode 1
#define RARAddOpcode 2
#define RARSubOpcode 3
#define RARJzOpcode 4
#define RARJnzOpcode 5
#define RARIncOpcode 6
#define RARDecOpcode 7
#define RARJmpOpcode 8
#define RARXorOpcode 9
#define RARAndOpcode 10
#define RAROrOpcode 11
#define RARTestOpcode 12
#define RARJsOpcode 13
#define RARJnsOpcode 14
#define RARJbOpcode 15
#define RARJbeOpcode 16
#define RARJaOpcode 17
#define RARJaeOpcode 18
#define RARPushOpcode 19
#define RARPopOpcode 20
#define RARCallOpcode 21
#define RARRetOpcode 22
#define RARNotOpcode 23
#define RARShlOpcode 24
#define RARShrOpcode 25
#define RARSarOpcode 26
#define RARNegOpcode 27
#define RARPushaOpcode 28
#define RARPopaOpcode 29
#define RARPushfOpcode 30
#define RARPopfOpcode 31
#define RARMovzxOpcode 32
#define RARMovsxOpcode 33
#define RARXchgOpcode 34
#define RARMulOpcode 35
#define RARDivOpcode 36
#define RARAdcOpcode 37
#define RARSbbOpcode 38
#define RARPrintOpcode 39

#define RAR0OperandsFlag 0
#define RAR1OperandFlag 1
#define RAR2OperandsFlag 2
#define RAROperandsFlag 3
#define RARHasByteModeFlag 4
#define RARJumpFlag 8
#define RARProcFlag 16
#define RARReadStatusFlag 32
#define RARWriteStatusFlag 64

static int OpcodeFlags[40]=
{
	[RARMovOpcode]=RAR2OperandsFlag | RARHasByteModeFlag,
	[RARCmpOpcode]=RAR2OperandsFlag | RARHasByteModeFlag | RARWriteStatusFlag,
	[RARAddOpcode]=RAR2OperandsFlag | RARHasByteModeFlag | RARWriteStatusFlag,
	[RARSubOpcode]=RAR2OperandsFlag | RARHasByteModeFlag | RARWriteStatusFlag,
	[RARJzOpcode]=RAR1OperandFlag | RARReadStatusFlag | RARReadStatusFlag,
	[RARJnzOpcode]=RAR1OperandFlag | RARReadStatusFlag | RARReadStatusFlag,
	[RARIncOpcode]=RAR1OperandFlag | RARHasByteModeFlag | RARWriteStatusFlag,
	[RARDecOpcode]=RAR1OperandFlag | RARHasByteModeFlag | RARWriteStatusFlag,
	[RARJmpOpcode]=RAR1OperandFlag | RARReadStatusFlag,
	[RARXorOpcode]=RAR2OperandsFlag | RARHasByteModeFlag | RARWriteStatusFlag,
	[RARAndOpcode]=RAR2OperandsFlag | RARHasByteModeFlag | RARWriteStatusFlag,
	[RAROrOpcode]=RAR2OperandsFlag | RARHasByteModeFlag | RARWriteStatusFlag,
	[RARTestOpcode]=RAR2OperandsFlag | RARHasByteModeFlag | RARWriteStatusFlag,
	[RARJsOpcode]=RAR1OperandFlag | RARReadStatusFlag | RARReadStatusFlag,
	[RARJnsOpcode]=RAR1OperandFlag | RARReadStatusFlag | RARReadStatusFlag,
	[RARJbOpcode]=RAR1OperandFlag | RARReadStatusFlag | RARReadStatusFlag,
	[RARJbeOpcode]=RAR1OperandFlag | RARReadStatusFlag | RARReadStatusFlag,
	[RARJaOpcode]=RAR1OperandFlag | RARReadStatusFlag | RARReadStatusFlag,
	[RARJaeOpcode]=RAR1OperandFlag | RARReadStatusFlag | RARReadStatusFlag,
	[RARPushOpcode]=RAR1OperandFlag,
	[RARPopOpcode]=RAR1OperandFlag,
	[RARCallOpcode]=RAR1OperandFlag | RARProcFlag,
	[RARRetOpcode]=RAR0OperandsFlag | RARProcFlag,
	[RARNotOpcode]=RAR1OperandFlag | RARHasByteModeFlag,
	[RARShlOpcode]=RAR2OperandsFlag | RARHasByteModeFlag | RARWriteStatusFlag,
	[RARShrOpcode]=RAR2OperandsFlag | RARHasByteModeFlag | RARWriteStatusFlag,
	[RARSarOpcode]=RAR2OperandsFlag | RARHasByteModeFlag | RARWriteStatusFlag,
	[RARNegOpcode]=RAR1OperandFlag | RARHasByteModeFlag | RARWriteStatusFlag,
	[RARPushaOpcode]=RAR0OperandsFlag,
	[RARPopaOpcode]=RAR0OperandsFlag,
	[RARPushfOpcode]=RAR0OperandsFlag | RARReadStatusFlag,
	[RARPopfOpcode]=RAR0OperandsFlag | RARWriteStatusFlag,
	[RARMovzxOpcode]=RAR2OperandsFlag,
	[RARMovsxOpcode]=RAR2OperandsFlag,
	[RARXchgOpcode]=RAR2OperandsFlag | RARHasByteModeFlag,
	[RARMulOpcode]=RAR2OperandsFlag | RARHasByteModeFlag,
	[RARDivOpcode]=RAR2OperandsFlag | RARHasByteModeFlag,
	[RARAdcOpcode]=RAR2OperandsFlag | RARHasByteModeFlag | RARReadStatusFlag | RARWriteStatusFlag,
	[RARSbbOpcode]=RAR2OperandsFlag | RARHasByteModeFlag | RARReadStatusFlag | RARWriteStatusFlag,
	[RARPrintOpcode]=RAR0OperandsFlag
};

static NSString *OpcodeNames[40]=
{
	[RARMovOpcode]=@"mov",[RARCmpOpcode]=@"cmp",[RARAddOpcode]=@"add",[RARSubOpcode]=@"sub",
	[RARJzOpcode]=@"jz",[RARJnzOpcode]=@"jnz",[RARIncOpcode]=@"inc",[RARDecOpcode]=@"dec",
	[RARJmpOpcode]=@"jmp",[RARXorOpcode]=@"xor",[RARAndOpcode]=@"and",[RAROrOpcode]=@"or",
	[RARTestOpcode]=@"test",[RARJsOpcode]=@"js",[RARJnsOpcode]=@"jns",[RARJbOpcode]=@"jb",
	[RARJbeOpcode]=@"jbe",[RARJaOpcode]=@"ja",[RARJaeOpcode]=@"jae",[RARPushOpcode]=@"push",
	[RARPopOpcode]=@"pop",[RARCallOpcode]=@"call",[RARRetOpcode]=@"ret",[RARNotOpcode]=@"not",
	[RARShlOpcode]=@"shl",[RARShrOpcode]=@"shr",[RARSarOpcode]=@"sar",[RARNegOpcode]=@"neg",
	[RARPushaOpcode]=@"pusha",[RARPopaOpcode]=@"popa",[RARPushfOpcode]=@"pushf",[RARPopfOpcode]=@"popf",
	[RARMovzxOpcode]=@"movzx",[RARMovsxOpcode]=@"movsx",[RARXchgOpcode]=@"xchg",[RARMulOpcode]=@"mul",
	[RARDivOpcode]=@"div",[RARAdcOpcode]=@"adc",[RARSbbOpcode]=@"sbb",[RARPrintOpcode]=@"print"
};



uint32_t CSInputNextRARVMNumber(CSInputBuffer *input)
{ 
	switch(CSInputNextBitString(input,2))
	{
		case 0: return CSInputNextBitString(input,4);
		case 1:
		{
			int val=CSInputNextBitString(input,8);
			if(val>=16) return val;
			else return 0xffffff00|(val<<4)|CSInputNextBitString(input,4);
		}
		case 2: return CSInputNextBitString(input,16);
		default: return CSInputNextLongBitString(input,32);
	}
}



@implementation XADRARVirtualMachine

-(id)init
{
	if(self=[super init])
	{
	}
	return self;
}

-(void)dealloc
{
	[super dealloc];
}

-(uint8_t *)memory { return memory; }

-(void)setRegisters:(uint32_t *)newregisters
{
	memcpy(registers,newregisters,sizeof(registers));
}

-(void)readMemoryAtAddress:(uint32_t)address length:(int)length toBuffer:(uint8_t *)buffer
{
	memcpy(buffer,&memory[address],length);
}

-(void)readMemoryAtAddress:(uint32_t)address length:(int)length toMutableData:(NSMutableData *)data
{
	[self readMemoryAtAddress:address length:length toBuffer:[data mutableBytes]];
}

-(void)writeMemoryAtAddress:(uint32_t)address length:(int)length fromBuffer:(const uint8_t *)buffer
{
	memcpy(&memory[address],buffer,length);
}

-(void)writeMemoryAtAddress:(uint32_t)address length:(int)length fromData:(NSData *)data
{
	[self writeMemoryAtAddress:address length:length fromBuffer:[data bytes]];
}

-(void)executeProgramCode:(XADRARProgramCode *)code
{
	flags=0; // ?
	//...
}

@end





@implementation XADRARProgramCode

-(id)initWithByteCode:(const uint8_t *)bytes length:(int)length
{
	if(self=[super init])
	{
		staticdata=nil;
		globalbackup=[NSMutableData new];

		[self parseByteCode:bytes length:length];
	}
	return self;
}

-(void)dealloc
{
	[staticdata release];
	[globalbackup release];
	[super dealloc];
}

-(void)parseByteCode:(const uint8_t *)bytes length:(int)length
{
	// TODO: deal with exceptions causing memory leaks

	if(length==0) [XADException raiseIllegalDataException];

	// Check XOR sum.
	uint8_t xor=0;
	for(int i=1;i<length;i++) xor^=bytes[i];
	if(xor!=bytes[0]) [XADException raiseIllegalDataException];

	// Calculate CRC for fast native path replacements.
	crc=XADCalculateCRC(0xffffffff,bytes,length,XADCRCTable_edb88320)^0xffffffff;

	CSInputBuffer *input=CSInputBufferAllocWithBuffer(&bytes[1],length-1,0);

	// Read static data, if any.
	if(CSInputNextBit(input))
	{
		int length=CSInputNextRARVMNumber(input)+1;
		NSMutableData *data=[NSMutableData dataWithLength:length];
		uint8_t *databytes=[data mutableBytes];

		for(int i=0;i<length;i++) databytes[i]=CSInputNextBitString(input,8);

		staticdata=data;
	}

	// Read instructions.
	while(CSInputBitsLeftInBuffer(input)>=8)
	{
		int opcode=CSInputNextBitString(input,4);
		if(opcode&0x08) opcode=((opcode<<2)|CSInputNextBitString(input,2))-24;

		BOOL bytemode=NO;
		if(OpcodeFlags[opcode]&RARHasByteModeFlag) bytemode=CSInputNextBitString(input,1);

		NSMutableString *str=[NSMutableString stringWithFormat:@"%@%@",OpcodeNames[opcode],bytemode?@"b":@""];

		int numargs=OpcodeFlags[opcode]&RAROperandsFlag;

		if(numargs>=1) [str appendString:@"\t"];
		if(numargs>=1) [str appendString:[self parseArgumentFromBuffer:input byteMode:bytemode]];
		if(numargs==2) [str appendString:@","];
		if(numargs==2) [str appendString:[self parseArgumentFromBuffer:input byteMode:bytemode]];

		//NSLog(@"%@",str);
	}

	CSInputBufferFree(input);
}

-(NSString *)parseArgumentFromBuffer:(CSInputBuffer *)input byteMode:(BOOL)bytemode
{
	if(CSInputNextBit(input))
	{
		int reg=CSInputNextBitString(input,3);
		return [NSString stringWithFormat:@"r%d",reg];
	}
	else
	{
		if(CSInputNextBit(input))
		{
			if(CSInputNextBit(input))
			{
				if(CSInputNextBit(input))
				{
					int32_t base=CSInputNextRARVMNumber(input);
					return [NSString stringWithFormat:@"(%d)",base];
				}
				else
				{
					int reg=CSInputNextBitString(input,3);
					int32_t base=CSInputNextRARVMNumber(input);
					return [NSString stringWithFormat:@"(%d,r%d)",base,reg];
				}
			}
			else
			{
				int reg=CSInputNextBitString(input,3);
				return [NSString stringWithFormat:@"(r%d)",reg];
			}
		}
		else
		{
			if(bytemode)
			{
				int val=CSInputNextBitString(input,8);
				return [NSString stringWithFormat:@"%d",val];
			}
			else
			{
				int32_t val=CSInputNextRARVMNumber(input);
				return [NSString stringWithFormat:@"%d",val];
			}
		}
	}
}

-(NSData *)staticData { return staticdata; }

-(NSMutableData *)globalBackup { return globalbackup; }

-(uint32_t)CRC { return crc; }

-(NSString *)disassemble
{
	return @"";
}

@end



@implementation XADRARProgramInvocation

-(id)initWithProgramCode:(XADRARProgramCode *)code globalData:(NSData *)data registers:(uint32_t *)registers
{
	if(self=[super init])
	{
		programcode=[code retain];

		if(data)
		{
			globaldata=[[NSMutableData alloc] initWithData:data];
			if([globaldata length]<XADRARProgramSystemGlobalSize) [globaldata setLength:XADRARProgramSystemGlobalSize];
		}
		else globaldata=[[NSMutableData alloc] initWithLength:XADRARProgramSystemGlobalSize];

		if(registers) memcpy(initialregisters,registers,sizeof(initialregisters));
		else memset(initialregisters,0,sizeof(initialregisters));
	}
	return self;
}

-(void)dealloc
{
	[programcode release];
	[globaldata release];
	[super dealloc];
}

-(XADRARProgramCode *)programCode { return programcode; }

-(NSData *)globalData { return globaldata; }

-(uint32_t)initialRegisterState:(int)n
{
	if(n<0||n>=8) [NSException raise:NSRangeException format:@"Attempted to set non-existent register"];

	return initialregisters[n];
}

-(void)setInitialRegisterState:(int)n toValue:(uint32_t)val
{
	if(n<0||n>=8) [NSException raise:NSRangeException format:@"Attempted to set non-existent register"];

	initialregisters[n]=val;
}

-(void)setGlobalValueAtOffset:(int)offs toValue:(uint32_t)val
{
	if(offs<0||offs+4>[globaldata length]) [NSException raise:NSRangeException format:@"Attempted to write outside global memory"];

	uint8_t *bytes=[globaldata mutableBytes];
	CSSetUInt32LE(&bytes[offs],val);
}

-(void)backupGlobalData
{
	NSMutableData *backup=[programcode globalBackup];
	if([globaldata length]>XADRARProgramSystemGlobalSize) [backup setData:globaldata];
	else [backup setLength:0];
}

-(void)restoreGlobalDataIfAvailable
{
	NSMutableData *backup=[programcode globalBackup];
	if([backup length]>XADRARProgramSystemGlobalSize) [globaldata setData:backup];
}

-(void)executeOnVitualMachine:(XADRARVirtualMachine *)vm
{
	int globallength=[globaldata length];
	if(globallength>XADRARProgramGlobalSize) globallength=XADRARProgramGlobalSize;
	[vm writeMemoryAtAddress:XADRARProgramGlobalAddress length:globallength fromData:globaldata];

	NSData *staticdata=[programcode staticData];
	if(staticdata)
	{
		int staticlength=[staticdata length];
		if(staticlength>XADRARProgramGlobalSize-globallength) staticlength=XADRARProgramGlobalSize-globallength;
		[vm writeMemoryAtAddress:XADRARProgramGlobalAddress length:staticlength fromData:staticdata];
	}

	[vm setRegisters:initialregisters];

	[vm executeProgramCode:programcode];

	uint32_t newgloballength=XADRARVirtualMachineRead32(vm,XADRARProgramGlobalAddress+0x30);
	if(newgloballength>XADRARProgramUserGlobalSize) newgloballength=XADRARProgramUserGlobalSize;
	if(newgloballength>0)
	{
		[vm readMemoryAtAddress:XADRARProgramGlobalAddress
		length:newgloballength+XADRARProgramSystemGlobalSize
		toMutableData:[globaldata mutableBytes]];
	}
	else [globaldata setLength:0];
}

@end
