#ifndef __RARVIRTUALMACHINE_H__
#define __RARVIRTUALMACHINE_H__

#include <stdint.h>
#include <stdbool.h>
#include <string.h>
#include <limits.h>

#define RARProgramMemorySize 0x40000
#define RARProgramMemoryMask (RARProgramMemorySize-1)
#define RARProgramWorkSize 0x3c000
#define RARProgramGlobalAddress RARProgramWorkSize
#define RARProgramGlobalSize 0x2000
#define RARProgramSystemGlobalSize 64
#define RARProgramUserGlobalSize (RARProgramGlobalSize-RARProgramSystemGlobalSize)

typedef struct RARVirtualMachine
{
	uint32_t registers[8];
	int flags;
	// TODO: align?
	uint8_t memory[RARProgramMemorySize+3]; // Let memory accesses at the end overflow.
	                                           // Possibly not 100% correct but unlikely to be a problem.
} RARVirtualMachine;

typedef struct RAROpcode
{
	void *opcodelabel;

	void *operand1getter;
	void *operand1setter;
	uint32_t value1;

	void *operand2getter;
	uint32_t value2;

	uint8_t instruction;
	uint8_t bytemode;
	uint8_t addressingmode1;
	uint8_t addressingmode2;

	#if UINTPTR_MAX==UINT32_MAX
	uint8_t padding[4]; // 32-bit machine, pad to 32 bytes
	#else
	uint8_t padding[20]; // 64-bit machine, pad to 64 bytes
	#endif
} RAROpcode;



void InitializeRARVirtualMachine(RARVirtualMachine *self);
void PrepareRARCode(RARVirtualMachine *self,RAROpcode *opcodes,int numopcodes);
void ExecuteRARCode(RARVirtualMachine *self,RAROpcode *opcodes,int numopcodes);

void SetRAROpcodeInstruction(RAROpcode *opcode,unsigned int instruction,bool bytemode);
void SetRAROpcodeOperand1(RAROpcode *opcode,unsigned int addressingmode,uint32_t value);
void SetRAROpcodeOperand2(RAROpcode *opcode,unsigned int addressingmode,uint32_t value);

bool RARInstructionHasByteMode(unsigned int instruction);
bool RARInstructionIsJump(unsigned int instruction);
int NumberOfRARInstructionOperands(unsigned int instruction);

char *DescribeRAROpcode(RAROpcode *opcode);
char *DescribeRARInstruction(RAROpcode *opcode);
char *DescribeRAROperand1(RAROpcode *opcode);
char *DescribeRAROperand2(RAROpcode *opcode);





static inline void SetRARVirtualMachineRegisters(RARVirtualMachine *self,uint32_t registers[8])
{
	memcpy(self->registers,registers,sizeof(self->registers));
}

static inline uint32_t RARVirtualMachineRead32(RARVirtualMachine *self,uint32_t address)
{
	return CSUInt32LE(&self->memory[address&RARProgramMemoryMask]);
}

static inline void RARVirtualMachineWrite32(RARVirtualMachine *self,uint32_t address,uint32_t val)
{
	CSSetUInt32LE(&self->memory[address&RARProgramMemoryMask],val);
}

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
#define RARNumberOfOpcodes 40

#define RARRegisterAddressingMode(n) (0+(n))
#define RARRegisterIndirectAddressingMode(n) (8+(n))
#define RARIndexedAbsoluteAddressingMode(n) (16+(n))
#define RARAbsoluteAddressingMode 24
#define RARImmediateAddressingMode 25
#define RARNumberOfAddressingModes 26

#endif
