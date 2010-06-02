#import "CSInputBuffer.h"
#import "RARVirtualMachine.h"


uint32_t CSInputNextRARVMNumber(CSInputBuffer *input);



@class XADRARProgramCode,XADRARProgramInvocation;

@interface XADRARVirtualMachine:NSObject
{
	RARVirtualMachine vm;
}

-(id)init;
-(void)dealloc;

-(uint8_t *)memory;

-(void)setRegisters:(uint32_t *)newregisters;

-(void)readMemoryAtAddress:(uint32_t)address length:(int)length toBuffer:(uint8_t *)buffer;
-(void)readMemoryAtAddress:(uint32_t)address length:(int)length toMutableData:(NSMutableData *)data;
-(void)writeMemoryAtAddress:(uint32_t)address length:(int)length fromBuffer:(const uint8_t *)buffer;
-(void)writeMemoryAtAddress:(uint32_t)address length:(int)length fromData:(NSData *)data;

-(uint32_t)readWordAtAddress:(uint32_t)address;
-(void)writeWordAtAddress:(uint32_t)address value:(uint32_t)value;

-(BOOL)executeProgramCode:(XADRARProgramCode *)code;

@end



@interface XADRARProgramCode:NSObject
{
	NSMutableData *opcodes;
	NSData *staticdata;
	NSMutableData *globalbackup;

	uint32_t crc;
}

-(id)initWithByteCode:(const uint8_t *)bytes length:(int)length;
-(void)dealloc;

-(BOOL)parseByteCode:(const uint8_t *)bytes length:(int)length;
-(void)parseOperandFromBuffer:(CSInputBuffer *)input addressingMode:(unsigned int *)modeptr
value:(uint32_t *)valueptr byteMode:(BOOL)bytemode isJump:(BOOL)isjump currentInstructionOffset:(int)instructionoffset;


-(RAROpcode *)opcodes;
-(int)numberOfOpcodes;
-(NSData *)staticData;
-(NSMutableData *)globalBackup;
-(uint32_t)CRC;

-(NSString *)disassemble;

@end



@interface XADRARProgramInvocation:NSObject
{
	XADRARProgramCode *programcode;

	uint32_t initialregisters[8];
	NSMutableData *globaldata;
}

-(id)initWithProgramCode:(XADRARProgramCode *)code globalData:(NSData *)data registers:(uint32_t *)registers;
-(void)dealloc;

-(XADRARProgramCode *)programCode;
-(NSData *)globalData;

-(uint32_t)initialRegisterState:(int)n;
-(void)setInitialRegisterState:(int)n toValue:(uint32_t)val;
-(void)setGlobalValueAtOffset:(int)offs toValue:(uint32_t)val;

-(void)backupGlobalData;
-(void)restoreGlobalDataIfAvailable;

-(BOOL)executeOnVitualMachine:(XADRARVirtualMachine *)vm;

@end
