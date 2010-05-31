#include "RARVirtualMachine.h"

#import <stdio.h>

#define RAR0OperandsFlag 0
#define RAR1OperandFlag 1
#define RAR2OperandsFlag 2
#define RAROperandsFlag 3
#define RARHasByteModeFlag 4
#define RARLabelOperandFlag 8
#define RARReadStatusFlag 16
#define RARWriteStatusFlag 32

static int InstructionFlags[40];
static char *InstructionNames[40];

void InitializeRARVirtualMachine(RARVirtualMachine *self)
{
}

void PrepareRARCode(RARVirtualMachine *self,RAROpcode *opcodes,int numopcodes)
{
}

void ExecuteRARCode(RARVirtualMachine *self,RAROpcode *opcodes,int numopcodes)
{
//	flags=0; // ?
}



// Program building

void SetRAROpcodeInstruction(RAROpcode *opcode,unsigned int instruction,bool bytemode)
{
	opcode->instruction=instruction;
	opcode->bytemode=bytemode;
}

void SetRAROpcodeOperand1(RAROpcode *opcode,unsigned int addressingmode,uint32_t value)
{
	opcode->addressingmode1=addressingmode;
	opcode->value1=value;
}

void SetRAROpcodeOperand2(RAROpcode *opcode,unsigned int addressingmode,uint32_t value)
{
	opcode->addressingmode2=addressingmode;
	opcode->value2=value;
}



// Instruction properties

bool RARInstructionHasByteMode(unsigned int instruction)
{
	if(instruction>=RARNumberOfOpcodes) return false;
	return (InstructionFlags[instruction]&RARHasByteModeFlag)!=0;
}

bool RARInstructionIsJump(unsigned int instruction)
{
	if(instruction>=RARNumberOfOpcodes) return false;
	return (InstructionFlags[instruction]&RARLabelOperandFlag)!=0;
}

int NumberOfRARInstructionOperands(unsigned int instruction)
{
	if(instruction>=RARNumberOfOpcodes) return 0;
	return InstructionFlags[instruction]&RAROperandsFlag;
}



// Disassembler

char *DescribeRAROpcode(RAROpcode *opcode)
{
	static char string[128];

	int numoperands=NumberOfRARInstructionOperands(opcode->instruction);

	char *instruction=DescribeRARInstruction(opcode);
	strcpy(string,instruction);

	if(numoperands==0) return string;

	strcat(string,"        "+strlen(instruction));
	strcat(string,DescribeRAROperand1(opcode));

	if(numoperands==1) return string;

	strcat(string,", ");
	strcat(string,DescribeRAROperand2(opcode));

	return string;
}

char *DescribeRARInstruction(RAROpcode *opcode)
{
	if(opcode->instruction>=RARNumberOfOpcodes) return "invalid";

	static char string[8];
	strcpy(string,InstructionNames[opcode->instruction]);
	if(opcode->bytemode) strcat(string,".b");
	return string;
}

static char *DescribeRAROperand(unsigned int addressingmode,uint32_t value)
{
	static char string[16];
	switch(addressingmode)
	{
		case RARRegisterAddressingMode(0): case RARRegisterAddressingMode(1):
		case RARRegisterAddressingMode(2): case RARRegisterAddressingMode(3):
		case RARRegisterAddressingMode(4): case RARRegisterAddressingMode(5):
		case RARRegisterAddressingMode(6): case RARRegisterAddressingMode(7):
			sprintf(string,"r%d",addressingmode-RARRegisterAddressingMode(0));
		break;


		case RARRegisterIndirectAddressingMode(0): case RARRegisterIndirectAddressingMode(1):
		case RARRegisterIndirectAddressingMode(2): case RARRegisterIndirectAddressingMode(3):
		case RARRegisterIndirectAddressingMode(4): case RARRegisterIndirectAddressingMode(5):
		case RARRegisterIndirectAddressingMode(6): case RARRegisterIndirectAddressingMode(7):
			sprintf(string,"(r%d)",addressingmode-RARRegisterIndirectAddressingMode(0));
		break;

		case RARIndexedAbsoluteAddressingMode(0): case RARIndexedAbsoluteAddressingMode(1):
		case RARIndexedAbsoluteAddressingMode(2): case RARIndexedAbsoluteAddressingMode(3):
		case RARIndexedAbsoluteAddressingMode(4): case RARIndexedAbsoluteAddressingMode(5):
		case RARIndexedAbsoluteAddressingMode(6): case RARIndexedAbsoluteAddressingMode(7):
			sprintf(string,"($%x+r%d)",value,addressingmode-RARIndexedAbsoluteAddressingMode(0));
		break;

		case RARAbsoluteAddressingMode:
			sprintf(string,"($%x)",value);
		break;

		case RARImmediateAddressingMode:
			sprintf(string,"$%x",value);
		break;
	}
	return string;
}

char *DescribeRAROperand1(RAROpcode *opcode)
{
	return DescribeRAROperand(opcode->addressingmode1,opcode->value1);
}

char *DescribeRAROperand2(RAROpcode *opcode)
{
	return DescribeRAROperand(opcode->addressingmode2,opcode->value2);
}



static int InstructionFlags[40]=
{
	[RARMovOpcode]=RAR2OperandsFlag | RARHasByteModeFlag,
	[RARCmpOpcode]=RAR2OperandsFlag | RARHasByteModeFlag | RARWriteStatusFlag,
	[RARAddOpcode]=RAR2OperandsFlag | RARHasByteModeFlag | RARWriteStatusFlag,
	[RARSubOpcode]=RAR2OperandsFlag | RARHasByteModeFlag | RARWriteStatusFlag,
	[RARJzOpcode]=RAR1OperandFlag | RARLabelOperandFlag | RARReadStatusFlag,
	[RARJnzOpcode]=RAR1OperandFlag | RARLabelOperandFlag | RARReadStatusFlag,
	[RARIncOpcode]=RAR1OperandFlag | RARHasByteModeFlag | RARWriteStatusFlag,
	[RARDecOpcode]=RAR1OperandFlag | RARHasByteModeFlag | RARWriteStatusFlag,
	[RARJmpOpcode]=RAR1OperandFlag | RARLabelOperandFlag,
	[RARXorOpcode]=RAR2OperandsFlag | RARHasByteModeFlag | RARWriteStatusFlag,
	[RARAndOpcode]=RAR2OperandsFlag | RARHasByteModeFlag | RARWriteStatusFlag,
	[RAROrOpcode]=RAR2OperandsFlag | RARHasByteModeFlag | RARWriteStatusFlag,
	[RARTestOpcode]=RAR2OperandsFlag | RARHasByteModeFlag | RARWriteStatusFlag,
	[RARJsOpcode]=RAR1OperandFlag | RARLabelOperandFlag | RARReadStatusFlag,
	[RARJnsOpcode]=RAR1OperandFlag | RARLabelOperandFlag | RARReadStatusFlag,
	[RARJbOpcode]=RAR1OperandFlag | RARLabelOperandFlag | RARReadStatusFlag,
	[RARJbeOpcode]=RAR1OperandFlag | RARLabelOperandFlag | RARReadStatusFlag,
	[RARJaOpcode]=RAR1OperandFlag | RARLabelOperandFlag | RARReadStatusFlag,
	[RARJaeOpcode]=RAR1OperandFlag | RARLabelOperandFlag | RARReadStatusFlag,
	[RARPushOpcode]=RAR1OperandFlag,
	[RARPopOpcode]=RAR1OperandFlag,
	[RARCallOpcode]=RAR1OperandFlag | RARLabelOperandFlag,
	[RARRetOpcode]=RAR0OperandsFlag | RARLabelOperandFlag,
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

static char *InstructionNames[40]=
{
	[RARMovOpcode]="mov",[RARCmpOpcode]="cmp",[RARAddOpcode]="add",[RARSubOpcode]="sub",
	[RARJzOpcode]="jz",[RARJnzOpcode]="jnz",[RARIncOpcode]="inc",[RARDecOpcode]="dec",
	[RARJmpOpcode]="jmp",[RARXorOpcode]="xor",[RARAndOpcode]="and",[RAROrOpcode]="or",
	[RARTestOpcode]="test",[RARJsOpcode]="js",[RARJnsOpcode]="jns",[RARJbOpcode]="jb",
	[RARJbeOpcode]="jbe",[RARJaOpcode]="ja",[RARJaeOpcode]="jae",[RARPushOpcode]="push",
	[RARPopOpcode]="pop",[RARCallOpcode]="call",[RARRetOpcode]="ret",[RARNotOpcode]="not",
	[RARShlOpcode]="shl",[RARShrOpcode]="shr",[RARSarOpcode]="sar",[RARNegOpcode]="neg",
	[RARPushaOpcode]="pusha",[RARPopaOpcode]="popa",[RARPushfOpcode]="pushf",[RARPopfOpcode]="popf",
	[RARMovzxOpcode]="movzx",[RARMovsxOpcode]="movsx",[RARXchgOpcode]="xchg",[RARMulOpcode]="mul",
	[RARDivOpcode]="div",[RARAdcOpcode]="adc",[RARSbbOpcode]="sbb",[RARPrintOpcode]="print"
};

