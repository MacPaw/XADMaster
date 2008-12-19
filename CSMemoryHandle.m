#import "CSMemoryHandle.h"


@implementation CSMemoryHandle



+(CSMemoryHandle *)memoryHandleForReadingData:(NSData *)data
{
	return [[[CSMemoryHandle alloc] initWithData:data] autorelease];
}

+(CSMemoryHandle *)memoryHandleForReadingBuffer:(const void *)buf length:(unsigned)len
{
	return [[[CSMemoryHandle alloc] initWithData:[NSData dataWithBytesNoCopy:(void *)buf length:len freeWhenDone:NO]] autorelease];
}

+(CSMemoryHandle *)memoryHandleForReadingMappedFile:(NSString *)filename
{
	return [[[CSMemoryHandle alloc] initWithData:[NSData dataWithContentsOfMappedFile:filename]] autorelease];
}

+(CSMemoryHandle *)memoryHandleForWriting
{
	return [[[CSMemoryHandle alloc] initWithData:[NSMutableData data]] autorelease];
}


-(id)initWithData:(NSData *)dataobj
{
	if(self=[super initWithName:[NSString stringWithFormat:@"%@ at 0x%x",[dataobj class],(int)dataobj]])
	{
		pos=0;
		data=[dataobj retain];
	}
	return self;
}

-(id)initAsCopyOf:(CSMemoryHandle *)other
{
	if(self=[super initAsCopyOf:other])
	{
		pos=other->pos;
		data=[other->data retain];
	}
	return self;
}

-(void)dealloc
{
	[data release];
	[super dealloc];
}





-(off_t)fileSize { return [data length]; }

-(off_t)offsetInFile { return pos; }

-(BOOL)atEndOfFile { return pos==[data length]; }



-(void)seekToFileOffset:(off_t)offs
{
	if(offs<0) [self _raiseNotSupported:_cmd];
	if(offs>[data length]) [self _raiseEOF];
	pos=offs;
}

-(void)seekToEndOfFile { pos=[data length]; }

//-(void)pushBackByte:(int)byte {}

-(int)readAtMost:(int)num toBuffer:(void *)buffer
{
	if(!num) return 0;

	unsigned int len=[data length];
	if(pos==len) return 0;
	if(pos+num>len) num=len-pos;
	memcpy(buffer,(uint8_t *)[data bytes]+pos,num);
	pos+=num;
	return num;
}

-(void)writeBytes:(int)num fromBuffer:(const void *)buffer
{
	if(![data isKindOfClass:[NSMutableData class]]) [self _raiseNotSupported:_cmd];
	NSMutableData *mdata=(NSMutableData *)data;

	if(pos+num>[mdata length]) [mdata setLength:pos+num];
	memcpy((uint8_t *)[mdata mutableBytes]+pos,buffer,num);
	pos+=num;
}


-(NSData *)fileContents { return data; }

-(NSData *)remainingFileContents
{
	if(pos==0) return data;
	else return [super remainingFileContents];
}

-(NSData *)readDataOfLength:(int)length
{
	unsigned int totallen=[data length];
	if(pos+length>totallen) [self _raiseEOF];
	NSData *subdata=[data subdataWithRange:NSMakeRange(pos,length)];
	pos+=length;
	return subdata;
}

-(NSData *)readDataOfLengthAtMost:(int)length;
{
	unsigned int totallen=[data length];
	if(pos+length>totallen) length=totallen-pos;
	NSData *subdata=[data subdataWithRange:NSMakeRange(pos,length)];
	pos+=length;
	return subdata;
}

-(NSData *)copyDataOfLength:(int)length { return [[self readDataOfLength:length] retain]; }

-(NSData *)copyDataOfLengthAtMost:(int)length { return [[self readDataOfLengthAtMost:length] retain]; }




-(NSData *)data { return data; }

-(NSMutableData *)mutableData
{
	if(![data isKindOfClass:[NSMutableData class]]) [self _raiseNotSupported:_cmd];
	return (NSMutableData *)data;
}

@end
