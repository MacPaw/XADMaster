#import "CSHandle.h"
#import "CSSubHandle.h"

#include <sys/stat.h>


NSString *CSOutOfMemoryException=@"CSOutOfMemoryException";
NSString *CSEndOfFileException=@"CSEndOfFileException";
NSString *CSNotImplementedException=@"CSNotImplementedException";
NSString *CSNotSupportedException=@"CSNotSupportedException";



static inline int16_t CSBEInt16(uint8_t *b) { return ((int16_t)b[0]<<8)|(int16_t)b[1]; }
static inline int32_t CSBEInt32(uint8_t *b) { return ((int32_t)b[0]<<24)|((int32_t)b[1]<<16)|((int32_t)b[2]<<8)|(int32_t)b[3]; }
static inline int64_t CSBEInt64(uint8_t *b) { return ((int64_t)b[0]<<56)|((int64_t)b[1]<<48)|((int64_t)b[2]<<40)|((int64_t)b[3]<<32)|((int64_t)b[4]<<24)||((int64_t)b[5]<<16)|((int64_t)b[6]<<8)|(int64_t)b[7]; }
static inline uint16_t CSBEUInt16(uint8_t *b) { return ((uint16_t)b[0]<<8)|(uint16_t)b[1]; }
static inline uint32_t CSBEUInt32(uint8_t *b) { return ((uint32_t)b[0]<<24)|((uint32_t)b[1]<<16)|((uint32_t)b[2]<<8)|(uint32_t)b[3]; }
static inline uint64_t CSBEUInt64(uint8_t *b) { return ((uint64_t)b[0]<<56)|((uint64_t)b[1]<<48)|((uint64_t)b[2]<<40)|((uint64_t)b[3]<<32)|((uint64_t)b[4]<<24)||((uint64_t)b[5]<<16)|((uint64_t)b[6]<<8)|(uint64_t)b[7]; }
static inline int16_t CSLEInt16(uint8_t *b) { return ((int16_t)b[1]<<8)|(int16_t)b[0]; }
static inline int32_t CSLEInt32(uint8_t *b) { return ((int32_t)b[3]<<24)|((int32_t)b[2]<<16)|((int32_t)b[1]<<8)|(int32_t)b[0]; }
static inline int64_t CSLEInt64(uint8_t *b) { return ((int64_t)b[7]<<56)|((int64_t)b[6]<<48)|((int64_t)b[5]<<40)|((int64_t)b[4]<<32)|((int64_t)b[3]<<24)||((int64_t)b[2]<<16)|((int64_t)b[1]<<8)|(int64_t)b[0]; }
static inline uint16_t CSLEUInt16(uint8_t *b) { return ((uint16_t)b[1]<<8)|(uint16_t)b[0]; }
static inline uint32_t CSLEUInt32(uint8_t *b) { return ((uint32_t)b[3]<<24)|((uint32_t)b[2]<<16)|((uint32_t)b[1]<<8)|(uint32_t)b[0]; }
static inline uint64_t CSLEUInt64(uint8_t *b) { return ((uint64_t)b[7]<<56)|((uint64_t)b[6]<<48)|((uint64_t)b[5]<<40)|((uint64_t)b[4]<<32)|((uint64_t)b[3]<<24)||((uint64_t)b[2]<<16)|((uint64_t)b[1]<<8)|(uint64_t)b[0]; }



@implementation CSHandle

-(id)initWithName:(NSString *)descname
{
	if(self=[super init])
	{
		name=[descname retain];

		bitoffs=-1;

		writebyte=0;
		writebitsleft=8;
	}
	return self;
}

-(id)initAsCopyOf:(CSHandle *)other
{
	if(self=[super init])
	{
		name=[[[other name] stringByAppendingString:@" (copy)"] retain];

		bitoffs=other->bitoffs;
		readbyte=other->readbyte;
		readbitsleft=other->readbitsleft;
		writebyte=other->writebyte;
		writebitsleft=other->writebitsleft;
	}
	return self;
}

-(void)dealloc
{
	[name release];
	[super dealloc];
}



-(off_t)fileSize { [self _raiseNotImplemented:_cmd]; return 0; }

-(off_t)offsetInFile { [self _raiseNotImplemented:_cmd]; return 0; }

-(BOOL)atEndOfFile { [self _raiseNotImplemented:_cmd]; return NO; }

-(void)seekToFileOffset:(off_t)offs { [self _raiseNotImplemented:_cmd]; }

-(void)seekToEndOfFile { [self _raiseNotImplemented:_cmd]; }

-(void)pushBackByte:(int)byte { [self _raiseNotImplemented:_cmd]; }

-(int)readAtMost:(int)num toBuffer:(void *)buffer { [self _raiseNotImplemented:_cmd]; return 0; }

-(void)writeBytes:(int)num fromBuffer:(const void *)buffer { [self _raiseNotImplemented:_cmd]; }




-(void)skipBytes:(off_t)bytes
{
	[self seekToFileOffset:[self offsetInFile]+bytes];
}

-(int8_t)readInt8;
{
	int8_t c;
	[self readBytes:1 toBuffer:&c];
	return c;
}

-(uint8_t)readUInt8
{
	uint8_t c;
	[self readBytes:1 toBuffer:&c];
	return c;
}

#define CSReadValueImpl(type,name,conv) \
-(type)name \
{ \
	uint8_t bytes[sizeof(type)]; \
	if([self readAtMost:sizeof(type) toBuffer:bytes]!=sizeof(type)) [self _raiseEOF]; \
	return conv(bytes); \
}

//CSReadValueImpl(int8_t,readInt8,(int8_t)*)
//CSReadValueImpl(uint8_t,readUInt8,(uint8_t)*)

CSReadValueImpl(int16_t,readInt16BE,CSBEInt16)
CSReadValueImpl(int32_t,readInt32BE,CSBEInt32)
CSReadValueImpl(int64_t,readInt64BE,CSBEInt64)
CSReadValueImpl(uint16_t,readUInt16BE,CSBEUInt16)
CSReadValueImpl(uint32_t,readUInt32BE,CSBEUInt32)
CSReadValueImpl(uint64_t,readUInt64BE,CSBEUInt64)

CSReadValueImpl(int16_t,readInt16LE,CSLEInt16)
CSReadValueImpl(int32_t,readInt32LE,CSLEInt32)
CSReadValueImpl(int64_t,readInt64LE,CSLEInt64)
CSReadValueImpl(uint16_t,readUInt16LE,CSLEUInt16)
CSReadValueImpl(uint32_t,readUInt32LE,CSLEUInt32)
CSReadValueImpl(uint64_t,readUInt64LE,CSLEUInt64)

CSReadValueImpl(uint32_t,readID,CSBEUInt32)

-(uint32_t)readBits:(int)bits
{
	int res=0;

	if([self offsetInFile]!=bitoffs) readbitsleft=0;
	while(bits)
	{
		if(!readbitsleft)
		{
			readbyte=[self readUInt8];
			bitoffs=[self offsetInFile];
			readbitsleft=8;
		}

		int num=bits;
		if(num>readbitsleft) num=readbitsleft;
		res=(res<<num)| ((readbyte>>(readbitsleft-num))&((1<<num)-1));

		bits-=num;
		readbitsleft-=num;
	}
	return res;
}

-(int32_t)readSignedBits:(int)bits
{
	uint32_t res=[self readBits:bits];
//	return res|((res&(1<<(bits-1)))*0xffffffff);
	return -(res&(1<<(bits-1)))|res;
}

-(void)flushReadBits { readbitsleft=0; }


-(NSData *)readLine
{
	int (*readatmost_ptr)(id,SEL,int,void *)=(void *)[self methodForSelector:@selector(readAtMost:toBuffer:)];

	NSMutableData *data=[NSMutableData data];
	for(;;)
	{
		uint8_t b[1];
		int actual=readatmost_ptr(self,@selector(readAtMost:toBuffer:),1,b);

		if(actual==0)
		if([data length]==0) [self _raiseEOF];
		else break;

		if(b[0]=='\n') break;

		[data appendBytes:b length:1];
	}

	const char *bytes=[data bytes];
	int length=[data length];
	if(length&&bytes[length-1]=='\r') [data setLength:length-1];

	return [NSData dataWithData:data];
}

-(NSString *)readLineWithEncoding:(NSStringEncoding)encoding
{
	return [[[NSString alloc] initWithData:[self readLine] encoding:encoding] autorelease];
}

-(NSString *)readUTF8Line
{
	return [[[NSString alloc] initWithData:[self readLine] encoding:NSUTF8StringEncoding] autorelease];
}


-(NSData *)fileContents
{
	[self seekToFileOffset:0];
	return [self remainingFileContents];
}

-(NSData *)remainingFileContents
{
	uint8_t buffer[16384];
	NSMutableData *data=[NSMutableData data];
	int actual;

	do
	{
		actual=[self readAtMost:sizeof(buffer) toBuffer:buffer];
		[data appendBytes:buffer length:actual];
	}
	while(actual==sizeof(buffer));

	return [NSData dataWithData:data];
}

-(NSData *)readDataOfLength:(int)length
{
	return [[self copyDataOfLength:length] autorelease];
}

-(NSData *)readDataOfLengthAtMost:(int)length;
{
	return [[self copyDataOfLengthAtMost:length] autorelease];
}

-(NSData *)copyDataOfLength:(int)length
{
	NSMutableData *data=[[NSMutableData alloc] initWithLength:length];
	if(!data) [self _raiseMemory];
	[self readBytes:length toBuffer:[data mutableBytes]];
	return data;
}

-(NSData *)copyDataOfLengthAtMost:(int)length
{
	NSMutableData *data=[[NSMutableData alloc] initWithLength:length];
	if(!data) [self _raiseMemory];
	int actual=[self readAtMost:length toBuffer:[data mutableBytes]];
	[data setLength:actual];
	return data;
}

-(void)readBytes:(int)num toBuffer:(void *)buffer
{
	if([self readAtMost:num toBuffer:buffer]!=num) [self _raiseEOF];
}



-(off_t)readAndDiscardAtMost:(off_t)num
{
	off_t skipped=0;
	uint8_t buf[16384];
	while(skipped<num)
	{
		off_t numbytes=num>sizeof(buf)?sizeof(buf):num;
		int actual=[self readAtMost:numbytes toBuffer:buf];
		skipped+=actual;
		if(actual!=numbytes) break;
	}
	return skipped;
}

-(void)readAndDiscardBytes:(off_t)num
{
	if([self readAndDiscardAtMost:num]!=num) [self _raiseEOF];
}



-(CSHandle *)subHandleOfLength:(off_t)length
{
	return [[[CSSubHandle alloc] initWithHandle:[[self copy] autorelease] from:[self offsetInFile] length:length] autorelease];
}

-(CSHandle *)subHandleWithRange:(NSRange)range;
{
	return [[[CSSubHandle alloc] initWithHandle:[[self copy] autorelease] from:range.location length:range.length] autorelease];
}

-(CSHandle *)nonCopiedSubHandleOfLength:(off_t)length
{
	return [[[CSSubHandle alloc] initWithHandle:self from:[self offsetInFile] length:length] autorelease];
}

-(CSHandle *)nonCopiedSubHandleWithRange:(NSRange)range;
{
	return [[[CSSubHandle alloc] initWithHandle:self from:range.location length:range.length] autorelease];
}



static inline void CSSetBEInt16(uint8_t *b,int16_t n) { b[0]=(n>>8)&0xff; b[1]=n&0xff; }
static inline void CSSetBEInt32(uint8_t *b,int32_t n) { b[0]=(n>>24)&0xff; b[1]=(n>>16)&0xff; b[2]=(n>>8)&0xff; b[3]=n&0xff; }
static inline void CSSetBEUInt16(uint8_t *b,uint16_t n) { b[0]=(n>>8)&0xff; b[1]=n&0xff; }
static inline void CSSetBEUInt32(uint8_t *b,uint32_t n) { b[0]=(n>>24)&0xff; b[1]=(n>>16)&0xff; b[2]=(n>>8)&0xff; b[3]=n&0xff; }
static inline void CSSetLEInt16(uint8_t *b,int16_t n) { b[1]=(n>>8)&0xff; b[0]=n&0xff; }
static inline void CSSetLEInt32(uint8_t *b,int32_t n) { b[3]=(n>>24)&0xff; b[2]=(n>>16)&0xff; b[1]=(n>>8)&0xff; b[0]=n&0xff; }
static inline void CSSetLEUInt16(uint8_t *b,uint16_t n) { b[1]=(n>>8)&0xff; b[0]=n&0xff; }
static inline void CSSetLEUInt32(uint8_t *b,uint32_t n) { b[3]=(n>>24)&0xff; b[2]=(n>>16)&0xff; b[1]=(n>>8)&0xff; b[0]=n&0xff; }


-(void)writeInt8:(int8_t)val { [self writeBytes:1 fromBuffer:(uint8_t *)&val]; }
-(void)writeUInt8:(uint8_t)val { [self writeBytes:1 fromBuffer:&val]; }

#define CSWriteValueImpl(type,name,conv) \
-(void)name:(type)val \
{ \
	uint8_t bytes[sizeof(type)]; \
	conv(bytes,val); \
	[self writeBytes:sizeof(type) fromBuffer:bytes]; \
}

CSWriteValueImpl(int16_t,writeInt16BE,CSSetBEInt16)
CSWriteValueImpl(int32_t,writeInt32BE,CSSetBEInt32)
//CSWriteValueImpl(int64_t,writeInt64BE,CSSetBEInt64)
CSWriteValueImpl(uint16_t,writeUInt16BE,CSSetBEUInt16)
CSWriteValueImpl(uint32_t,writeUInt32BE,CSSetBEUInt32)
//CSWriteValueImpl(uint64_t,writeUInt64BE,CSSetBEUInt64)

CSWriteValueImpl(int16_t,writeInt16LE,CSSetLEInt16)
CSWriteValueImpl(int32_t,writeInt32LE,CSSetLEInt32)
//CSWriteValueImpl(int64_t,writeInt64LE,CSSetLEInt64)
CSWriteValueImpl(uint16_t,writeUInt16LE,CSSetLEUInt16)
CSWriteValueImpl(uint32_t,writeUInt32LE,CSSetLEUInt32)
//CSWriteValueImpl(uint64_t,writeUInt64LE,CSSetLEUInt64)

CSWriteValueImpl(uint32_t,writeID,CSSetBEUInt32)


-(void)writeBits:(int)bits value:(uint32_t)val
{
	int bitsleft=bits;
	while(bitsleft)
	{
		if(!writebitsleft)
		{
			[self writeUInt8:writebyte];
			writebyte=0;
			writebitsleft=8;
		}

		int num=bitsleft;
		if(num>writebitsleft) num=writebitsleft;
		writebyte|=((val>>(bitsleft-num))&((1<<num)-1))<<(writebitsleft-num);

		bitsleft-=num;
		writebitsleft-=num;
	}
}

-(void)writeSignedBits:(int)bits value:(int32_t)val;
{
	[self writeBits:bits value:val];
}

-(void)flushWriteBits
{
	if(writebitsleft!=8) [self writeUInt8:writebyte];
	writebyte=0;
	writebitsleft=8;
}

-(void)writeData:(NSData *)data
{
	[self writeBytes:[data length] fromBuffer:[data bytes]];
}




/*-(void)_raiseClosed
{
	[NSException raise:@"CSFileNotOpenException"
	format:@"Attempted to read from file \"%@\", which was not open.",name];
}*/

-(void)_raiseMemory
{
	[NSException raise:CSOutOfMemoryException
	format:@"Out of memory while attempting to read from file \"%@\" (%@).",name,[self class]];
}

-(void)_raiseEOF
{
	[NSException raise:CSEndOfFileException
	format:@"Attempted to read past the end of file \"%@\" (%@).",name,[self class]];
}

-(void)_raiseNotImplemented:(SEL)selector
{
	[NSException raise:CSNotImplementedException
	format:@"Attempted to use unimplemented method +[%@ %@] when reading from file \"%@\".",[self class],NSStringFromSelector(selector),name];
}

-(void)_raiseNotSupported:(SEL)selector
{
	[NSException raise:CSNotSupportedException
	format:@"Attempted to use unsupported method +[%@ %@] when reading from file \"%@\".",[self class],NSStringFromSelector(selector),name];
}


-(NSString *)name { return name; }

-(NSString *)description
{
	return [NSString stringWithFormat:@"%@ for \"%@\", position %qu",
	[self class],name,[self offsetInFile]];
}



-(id)copyWithZone:(NSZone *)zone
{
	return [[[self class] allocWithZone:zone] initAsCopyOf:self];
}

@end
