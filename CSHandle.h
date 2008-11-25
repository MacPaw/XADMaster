#import <Foundation/Foundation.h>
#import <stdint.h>


#define CSHandleMaxLength 0x7fffffffffffffff

extern NSString *CSOutOfMemoryException;
extern NSString *CSEndOfFileException;
extern NSString *CSNotImplementedException;
extern NSString *CSNotSupportedException;



@interface CSHandle:NSObject <NSCopying>
{
	NSString *name;
	off_t bitoffs;
	uint8_t readbyte,readbitsleft;
	uint8_t writebyte,writebitsleft;
}

-(id)initWithName:(NSString *)descname;
-(id)initAsCopyOf:(CSHandle *)other;
-(void)dealloc;


// Methods implemented by subclasses

-(off_t)fileSize;
-(off_t)offsetInFile;
-(BOOL)atEndOfFile;
-(void)seekToFileOffset:(off_t)offs;
-(void)seekToEndOfFile;
-(void)pushBackByte:(int)byte;
-(int)readAtMost:(int)num toBuffer:(void *)buffer;
-(void)writeBytes:(int)num fromBuffer:(const void *)buffer;



// Utility methods

-(void)skipBytes:(off_t)bytes;

-(int8_t)readInt8;
-(uint8_t)readUInt8;

-(int16_t)readInt16BE;
-(int32_t)readInt32BE;
-(int64_t)readInt64BE;
-(uint16_t)readUInt16BE;
-(uint32_t)readUInt32BE;
-(uint64_t)readUInt64BE;

-(int16_t)readInt16LE;
-(int32_t)readInt32LE;
-(int64_t)readInt64LE;
-(uint16_t)readUInt16LE;
-(uint32_t)readUInt32LE;
-(uint64_t)readUInt64LE;

-(uint32_t)readID;

-(uint32_t)readBits:(int)bits;
-(int32_t)readSignedBits:(int)bits;
-(void)flushReadBits;

-(NSData *)readLine;
-(NSString *)readLineWithEncoding:(NSStringEncoding)encoding;
-(NSString *)readUTF8Line;

-(NSData *)fileContents;
-(NSData *)remainingFileContents;
-(NSData *)readDataOfLength:(int)length;
-(NSData *)readDataOfLengthAtMost:(int)length;
-(NSData *)copyDataOfLength:(int)length;
-(NSData *)copyDataOfLengthAtMost:(int)length;
-(void)readBytes:(int)num toBuffer:(void *)buffer;
-(void)readAndDiscardBytes:(off_t)num;

-(CSHandle *)subHandleOfLength:(off_t)length;
-(CSHandle *)subHandleWithRange:(NSRange)range;
-(CSHandle *)nonCopiedSubHandleOfLength:(off_t)length;
-(CSHandle *)nonCopiedSubHandleWithRange:(NSRange)range;

-(void)writeInt8:(int8_t)val;
-(void)writeUInt8:(uint8_t)val;

-(void)writeInt16BE:(int16_t)val;
-(void)writeInt32BE:(int32_t)val;
//-(void)writeInt64BE:(int64_t)val;
-(void)writeUInt16BE:(uint16_t)val;
-(void)writeUInt32BE:(uint32_t)val;
//-(void)writeUInt64BE:(uint64_t)val;

-(void)writeInt16LE:(int16_t)val;
-(void)writeInt32LE:(int32_t)val;
//-(void)writeInt64LE:(int64_t)val;
-(void)writeUInt16LE:(uint16_t)val;
-(void)writeUInt32LE:(uint32_t)val;
//-(void)writeUInt64LE:(uint64_t)val;

-(void)writeID:(uint32_t)val;

-(void)writeBits:(int)bits value:(uint32_t)val;
-(void)writeSignedBits:(int)bits value:(int32_t)val;
-(void)flushWriteBits;

-(void)writeData:(NSData *)data;

//-(void)_raiseClosed;
-(void)_raiseMemory;
-(void)_raiseEOF;
-(void)_raiseNotImplemented:(SEL)selector;
-(void)_raiseNotSupported:(SEL)selector;

-(NSString *)name;
-(NSString *)description;

-(id)copyWithZone:(NSZone *)zone;

@end
