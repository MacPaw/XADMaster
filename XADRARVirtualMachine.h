#import "CSInputBuffer.h"



uint32_t CSInputNextRARVMNumber(CSInputBuffer *input);



#define XADRARProgramMemorySize 0x40000
#define XADRARProgramMemoryMask (XADRARProgramMemorySize-1)
#define XADRARProgramGlobalAddress 0x3c000
#define XADRARProgramGlobalSize 0x2000
#define XADRARProgramSystemGlobalSize 64
#define XADRARProgramUserGlobalSize (XADRARProgramGlobalSize-XADRARProgramSystemGlobalSize)

@class XADRARProgramCode,XADRARProgramInvocation;

@interface XADRARVirtualMachine:NSObject
{
	uint32_t registers[8];
	int flags;
	// TODO: align?
	@public
	uint8_t memory[XADRARProgramMemorySize+3]; // Let memory accesses at the end overflow.
	                                           // Possibly not 100% correct but unlikely to be a problem.
}

-(id)init;
-(void)dealloc;

-(uint8_t *)memory;

-(void)setRegisters:(uint32_t *)newregisters;

-(void)readMemoryAtAddress:(uint32_t)address length:(int)length toBuffer:(uint8_t *)buffer;
-(void)readMemoryAtAddress:(uint32_t)address length:(int)length toMutableData:(NSMutableData *)data;
-(void)writeMemoryAtAddress:(uint32_t)address length:(int)length fromBuffer:(const uint8_t *)buffer;
-(void)writeMemoryAtAddress:(uint32_t)address length:(int)length fromData:(NSData *)data;

-(void)executeProgramCode:(XADRARProgramCode *)code;

@end



@interface XADRARProgramCode:NSObject
{
	NSData *staticdata;
	NSMutableData *globalbackup;

	uint32_t crc;
}

-(id)initWithByteCode:(const uint8_t *)bytes length:(int)length;
-(void)dealloc;

-(void)parseByteCode:(const uint8_t *)bytes length:(int)length;
-(NSString *)parseArgumentFromBuffer:(CSInputBuffer *)input byteMode:(BOOL)bytemode;

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

-(uint32_t)register:(int)n;
-(void)setRegister:(int)n toValue:(uint32_t)val;
-(void)setGlobalValueAtOffset:(int)offs toValue:(uint32_t)val;

-(void)backupGlobalData;
-(void)restoreGlobalDataIfAvailable;

-(void)executeOnVitualMachine:(XADRARVirtualMachine *)vm;

@end




static inline uint32_t XADRARVirtualMachineRead32(XADRARVirtualMachine *self,uint32_t address)
{
	return CSUInt32LE(&self->memory[address&XADRARProgramMemoryMask]);
}

static inline uint32_t XADRARVirtualMachineWrite32(XADRARVirtualMachine *self,uint32_t address,uint32_t val)
{
	CSSetUInt32LE(&self->memory[address&XADRARProgramMemoryMask],val);
}
