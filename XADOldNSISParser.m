#import "XADOldNSISParser.h"
#import "CSZlibHandle.h"
#import "XADDeflateHandle.h"
#import "NSDateXAD.h"

// Beware all who venture within: This is nothing but a big pile of heuristics, hacks and
// kludges. That it works at all is nothing short of a miracle.

static int IndexOfLargestEntry(const int *entries,int num);

static BOOL IsOlderSignature(const uint8_t *ptr)
{
	static const uint8_t OlderSignature[16]={0xec,0xbe,0xad,0xde,0x4e,0x75,0x6c,0x6c,0x53,0x6f,0x66,0x74,0x49,0x6e,0x73,0x74};
	static const uint8_t OlderSignatureCRC[16]={0xed,0xbe,0xad,0xde,0x4e,0x75,0x6c,0x6c,0x53,0x6f,0x66,0x74,0x49,0x6e,0x73,0x74};
	if(memcmp(ptr,OlderSignature,16)==0) return YES;
	if(memcmp(ptr,OlderSignatureCRC,16)==0) return YES;
	return NO;
}

static BOOL IsOldSignature(const uint8_t *ptr)
{
	static const uint8_t OldSignature[16]={0xef,0xbe,0xad,0xde,0x4e,0x75,0x6c,0x6c,0x53,0x6f,0x66,0x74,0x49,0x6e,0x73,0x74};
	if(memcmp(ptr+4,OldSignature,16)!=0) return NO;
	if(CSUInt32LE(ptr)&2) return NO; // uninstaller
	return YES;
}

static BOOL IsNewSignature(const uint8_t *ptr)
{
	static const uint8_t NewSignature[16]={0xef,0xbe,0xad,0xde,0x4e,0x75,0x6c,0x6c,0x73,0x6f,0x66,0x74,0x49,0x6e,0x73,0x74};
	if(memcmp(ptr+4,NewSignature,16)!=0) return NO;
	if(CSUInt32LE(ptr)&2) return NO; // uninstaller
	return YES;
}

@implementation XADOldNSISParser

+(int)requiredHeaderSize { return 0x10000; }

+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name
{
	const uint8_t *bytes=[data bytes];
	int length=[data length];

	for(int offs=0;offs<length+4+16;offs+=512)
	{
		if(IsOlderSignature(bytes+offs)) return YES;
		if(IsOldSignature(bytes+offs)) return YES;
		if(IsNewSignature(bytes+offs)) return YES;
	}
	return NO;
}


-(void)parse
{
	CSHandle *fh=[self handle];

	[fh skipBytes:512];
	for(;;)
	{
		uint8_t buf[20];
		[fh readBytes:sizeof(buf) toBuffer:buf];
		[fh skipBytes:-(int)sizeof(buf)];

		if(IsOlderSignature(buf)) { [self parseOlderFormat]; return; }
		if(IsOldSignature(buf)) { [self parseOldFormat]; return; }
		if(IsNewSignature(buf)) { [self parseNewishFormat]; return; }
		[fh skipBytes:512];
	}
}

// Versions 1.1o to 1.2g - opcode 3, stride 7
-(void)parseOlderFormat
{
	CSHandle *fh=[self handle];

	uint32_t signature=[fh readUInt32LE];
	[fh skipBytes:12];

	uint32_t headerlength=[fh readUInt32LE];
	uint32_t headeroffset=[fh readUInt32LE];
	uint32_t totallength=[fh readUInt32LE];

	uint32_t datalength=totallength-28;
	if(signature&1) datalength-=4;

	if(headerlength+headeroffset+4<totallength)
	{
		// Versions 1.1o to 1.1x
		uint32_t complength=headerlength;
		uint32_t uncomplength=headeroffset;

NSLog(@"path 1a");
		base=[fh offsetInFile]+complength;

		CSHandle *hh=[fh nonCopiedSubHandleOfLength:complength];
		if(uncomplength) hh=[CSZlibHandle zlibHandleWithHandle:hh length:uncomplength];
		NSData *header=[hh readDataOfLength:uncomplength];

		NSDictionary *blocks=[self findBlocksWithTotalSize:datalength];
		NSDictionary *strings=[self findStringTableInData:header maxOffsets:7];

		int stride,phase;
		int extractopcode=[self findOpcodeWithData:header strings:strings blocks:blocks
		opcodePossibilities:(int[]){3} count:1
		stridePossibilities:(int[]){7} count:1
		foundStride:&stride foundPhase:&phase];

		[self parseOpcodesWithHeader:header strings:strings blocks:blocks
		extractOpcode:extractopcode directoryOpcode:extractopcode-2 directoryArgument:0
		startOffset:(stride+phase)*4 endOffset:stringtable stride:stride];
	}
	else
	{
		// Versions 1.1y to 1.2g
NSLog(@"path 1b");
		CSHandle *fh=[self handle];

		base=[fh offsetInFile];

		NSDictionary *blocks=[self findBlocksWithTotalSize:datalength];
		CSHandle *hh=[self handleForBlockAtOffset:headeroffset length:headerlength];
		NSData *header=[hh readDataOfLength:headerlength];
		NSDictionary *strings=[self findStringTableInData:header maxOffsets:16];

		int stride,phase;
		int extractopcode=[self findOpcodeWithData:header strings:strings blocks:blocks
		opcodePossibilities:(int[]){3} count:1
		stridePossibilities:(int[]){7} count:1
		foundStride:&stride foundPhase:&phase];

		[self parseOpcodesWithHeader:header strings:strings blocks:blocks
		extractOpcode:extractopcode directoryOpcode:extractopcode-2 directoryArgument:0
		startOffset:(stride+phase)*4 endOffset:stringtable stride:stride];
	}
}

// Versions 1.30 to 1.59 - opcodes 4, 5, strides 7, 6
-(void)parseOldFormat
{
	CSHandle *fh=[self handle];

	uint32_t flags=[fh readUInt32LE];
	[fh skipBytes:16];

	uint32_t headerlength=[fh readUInt32LE];
	uint32_t headeroffset=[fh readUInt32LE];
	uint32_t totallength=[fh readUInt32LE];

	uint32_t datalength=totallength-32;
	if(flags&1) datalength-=4;

	base=[fh offsetInFile];

	NSDictionary *blocks=[self findBlocksWithTotalSize:datalength];
	CSHandle *hh=[self handleForBlockAtOffset:headeroffset length:headerlength];
	NSData *header=[hh readDataOfLength:headerlength];
	NSDictionary *strings=[self findStringTableInData:header maxOffsets:16];

	int stride,phase;
	int extractopcode=[self findOpcodeWithData:header strings:strings blocks:blocks
	opcodePossibilities:(int[]){4,5} count:2
	stridePossibilities:(int[]){6,7} count:2
	foundStride:&stride foundPhase:&phase];

	if(stride==6&&extractopcode==4)
	{
NSLog(@"path 2b");
		// Versions 1.54 - 1.59 - new directory opcode
		[self parseOpcodesWithHeader:header strings:strings blocks:blocks
		extractOpcode:4 directoryOpcode:3 directoryArgument:1
		startOffset:(stride+phase)*4 endOffset:stringtable stride:stride];
	}
	else
	{
NSLog(@"path 2a");
		// Versions 1.30 - 1.53 - old directory opcode
		[self parseOpcodesWithHeader:header strings:strings blocks:blocks
		extractOpcode:extractopcode directoryOpcode:extractopcode-2 directoryArgument:0
		startOffset:(stride+phase)*4 endOffset:stringtable stride:stride];
	}
}

// Versions 1.60 to
-(void)parseNewishFormat
{
NSLog(@"path 3");
	CSHandle *fh=[self handle];

	uint32_t flags=[fh readUInt32LE];
	[fh skipBytes:16];

	uint32_t headerlength=[fh readUInt32LE];
	uint32_t totallength=[fh readUInt32LE];

	uint32_t datalength=totallength-32;
	if(flags&1) datalength-=4;

	uint32_t headercompsize=[fh readUInt32LE]&0x7fffffff;
	base=[fh offsetInFile]+headercompsize;

	NSDictionary *blocks=[self findBlocksWithTotalSize:datalength];
	CSHandle *hh=[self handleForBlockAtOffset:-(int)headercompsize-4 length:headerlength];
	NSData *header=[hh readDataOfLength:headerlength];

	NSDictionary *strings=[self findStringTableInData:header maxOffsets:0];

	int stride,phase;
	int extractopcode=[self findOpcodeWithData:header strings:strings blocks:blocks
	opcodePossibilities:(int[]){15,17,18} count:3
	stridePossibilities:(int[]){6} count:1
	foundStride:&stride foundPhase:&phase];

	int diropcode;
	if(extractopcode==18) diropcode=12;
	else diropcode=11;

	[self parseOpcodesWithHeader:header strings:strings blocks:blocks
	extractOpcode:extractopcode directoryOpcode:diropcode directoryArgument:1
	startOffset:(stride+phase)*4 endOffset:stringtable stride:stride];
}




-(void)parseOpcodesWithHeader:(NSData *)header strings:(NSDictionary *)strings blocks:(NSDictionary *)blocks
extractOpcode:(int)extractopcode directoryOpcode:(int)diropcode directoryArgument:(int)dirarg
startOffset:(int)startoffs endOffset:(int)endoffs stride:(int)stride
{
	const uint8_t *bytes=[header bytes];
	int length=[header length];
	XADPath *dir=[self XADPath];

	for(int i=startoffs;i<endoffs&&i+24<=length;i+=4*stride)
	{
		int opcode=CSUInt32LE(bytes+i);
		uint32_t args[6];
		for(int j=1;j<stride;j++) args[j-1]=CSUInt32LE(bytes+i+j*4);

		if(opcode==extractopcode)
		{
			uint32_t overwrite=args[0];
			NSData *filename=[strings objectForKey:[NSNumber numberWithInt:args[1]]];
			NSNumber *offs=[NSNumber numberWithUnsignedInt:args[2]];
			NSNumber *block=[blocks objectForKey:offs];
			uint32_t datetimehigh=args[3];
			uint32_t datetimelow=args[4];

			if(overwrite<4&&filename&&block)
			{
				uint32_t len=[block unsignedIntValue];

				NSMutableDictionary *dict=[NSMutableDictionary dictionaryWithObjectsAndKeys:
					[dir pathByAppendingPathComponent:[self XADStringWithData:filename]],XADFileNameKey,
					[NSNumber numberWithUnsignedInt:len&0x7fffffff],XADCompressedSizeKey,
					[NSDate XADDateWithWindowsFileTimeLow:datetimelow high:datetimehigh],XADLastModificationDateKey,
					offs,@"NSISDataOffset",
				nil];

				if(len&0x80000000)
				{
					[dict setObject:[self XADStringWithString:@"Deflate"] forKey:XADCompressionNameKey];
				}
				else
				{
					[dict setObject:[self XADStringWithString:@"None"] forKey:XADCompressionNameKey];
					[dict setObject:[NSNumber numberWithUnsignedInt:len&0x7fffffff] forKey:XADFileSizeKey];
				}

				[self addEntryWithDictionary:dict];

				continue;
			}
		}
		if(opcode==diropcode)
		{
			if(args[1]==dirarg&&args[2]==0&&args[3]==0&&args[4]==0)
			{
				NSData *path=[strings objectForKey:[NSNumber numberWithInt:args[0]]];
				dir=[self cleanedPathForData:path];
				continue;
			}
		}
	}
}



-(NSDictionary *)findBlocksWithTotalSize:(uint32_t)totalsize
{
	NSMutableDictionary *dict=[NSMutableDictionary dictionary];

	CSHandle *fh=[self handle];
	[fh seekToFileOffset:base];

	uint32_t size=0;
	while(size<totalsize)
	{
		uint32_t val=[fh readUInt32LE];
		uint32_t len=val&0x7fffffff;
		[dict setObject:[NSNumber numberWithUnsignedInt:val] forKey:[NSNumber numberWithInt:size]];
		[fh skipBytes:len];
		size+=len+4;
	}

	return dict;
}

-(NSDictionary *)findStringTableInData:(NSData *)data maxOffsets:(int)maxnumoffsets
{
	const uint8_t *bytes=[data bytes];
	int length=[data length];

	// Find last location with three zero bytes in a row. The string table shouldn't be anywhere
	// before this. (Could perhaps work with just doubles, too.)
	int lasttriple=0;
	for(int i=0;i<length-2;i++)
	{
		if(bytes[i]==0&&bytes[i+1]==0&&bytes[i+2]==0) lasttriple=i;
	}

	// Scan the start of the header for things that look like string table offsets.
	uint32_t stringoffset[maxnumoffsets];
	int numoffsets=0;
	int maxoffset=0;
	for(int i=0;i+4<=length && i<maxnumoffsets*4;i+=4)
	{
		uint32_t val=CSUInt32LE(bytes+i);
		if(val!=0 && val+lasttriple+3<length)
		{
			stringoffset[numoffsets]=val;
			numoffsets++;
			if(val>maxoffset) maxoffset=val;
		}
	}

	// Then start testing offsets trying to find one that has null bytes just before, or at,
	// all the string first bytes found in the header.
	stringtable=0;
	for(int i=lasttriple+3;i+maxoffset<length;i++)
	{
		int startcount=0;
		int endcount=0;
		for(int j=0;j<numoffsets;j++)
		{
			if(bytes[i+stringoffset[j]-1]==0) startcount++;
			else if(bytes[i+stringoffset[j]]==0) endcount++;
		}
		if(startcount+endcount==numoffsets && endcount<2)
		{
			stringtable=i;
			break;
		}
	}

	if(!stringtable) [XADException raiseNotSupportedException];

	// Extract strings
	NSMutableDictionary *dict=[NSMutableDictionary dictionary];
	int start=stringtable;
	for(int i=stringtable;i<length;i++)
	{
		if(bytes[i]==0)
		{
			[dict setObject:[NSData dataWithBytes:&bytes[start] length:i-start]
			forKey:[NSNumber numberWithInt:start-stringtable]];
			start=i+1;
		}
	}

	return dict;
}

-(int)findOpcodeWithData:(NSData *)data strings:(NSDictionary *)strings blocks:(NSDictionary *)blocks
opcodePossibilities:(int *)possibleopcodes count:(int)numpossibleopcodes
stridePossibilities:(int *)possiblestrides count:(int)numpossiblestrides
foundStride:(int *)strideptr foundPhase:(int *)phaseptr
{
	// Heuristic to find the size of entries, and the opcode for extract file entries.
	// Find candidates for extract opcodes, and measure the distances between them and
	// which opcodes they have.
	const uint8_t *bytes=[data bytes];
	int length=[data length];
	//NSLog(@"%@ %@ %@",data,strings,blocks);

	int maxpossiblestride=possiblestrides[IndexOfLargestEntry(possiblestrides,numpossiblestrides)];
	int strideopcodecounts[numpossiblestrides][numpossibleopcodes];
	int stridephasecounts[numpossiblestrides][maxpossiblestride];
	memset(strideopcodecounts,0,sizeof(strideopcodecounts));
	memset(stridephasecounts,0,sizeof(stridephasecounts));

	int lastpos=0;
	for(int i=24;i<stringtable&&i+24<=length;i+=4)
	{
		int opcode=CSUInt32LE(bytes+i);

		for(int j=0;j<numpossibleopcodes;j++)
		if(opcode==possibleopcodes[j]) // possible ExtractFile
		{
			uint32_t overwrite=CSUInt32LE(bytes+i+4);
			uint32_t filenameoffs=CSUInt32LE(bytes+i+8);
			uint32_t dataoffs=CSUInt32LE(bytes+i+12);

			if(overwrite<4)
			if([strings objectForKey:[NSNumber numberWithInt:filenameoffs]])
			if([blocks objectForKey:[NSNumber numberWithInt:dataoffs]])
			{
				int pos=i/4;
				for(int k=0;k<numpossiblestrides;k++)
				if((pos-lastpos)%possiblestrides[k]==0)
				{
					strideopcodecounts[k][j]++;
					stridephasecounts[k][pos%possiblestrides[k]]++;
				}
				lastpos=pos;
			}
			break;
		}
	}

	int totalstrideopcodes[numpossiblestrides];
	memset(totalstrideopcodes,0,sizeof(totalstrideopcodes));
	for(int i=0;i<numpossiblestrides;i++)
	{
		for(int j=0;j<numpossibleopcodes;j++)
		totalstrideopcodes[i]+=strideopcodecounts[i][j];
	}

	int strideindex=IndexOfLargestEntry(totalstrideopcodes,numpossiblestrides);
	int opcodeindex=IndexOfLargestEntry(strideopcodecounts[strideindex],numpossibleopcodes);
	int phase=IndexOfLargestEntry(stridephasecounts[strideindex],possiblestrides[strideindex]);

	//NSLog(@"stride %d, opcode %d, phase %d",possiblestrides[strideindex],possibleopcodes[opcodeindex],phase);

	if(strideptr) *strideptr=possiblestrides[strideindex];
	if(phaseptr) *phaseptr=phase;
	return possibleopcodes[opcodeindex];
}




-(XADPath *)cleanedPathForData:(NSData *)data
{
	const uint8_t *bytes=[data bytes];
	int length=[data length];

	if(length==8 && memcmp(bytes,"$INSTDIR",8)==0) return [self XADPath];
	else if(length==1 && (bytes[0]==0xea || bytes[0]==0xee || bytes[0]==0xf3 || bytes[0]==0xf7)) return [self XADPath];
	else if(length>=9 && memcmp(bytes,"$INSTDIR\\",9)==0) return [self XADPathWithBytes:bytes+9 length:length-9 separators:XADWindowsPathSeparator];
	else if(length>=1 && (bytes[0]==0xea || bytes[0]==0xee || bytes[0]==0xf3 || bytes[0]==0xf7) && bytes[1]=='\\') return [self XADPathWithBytes:bytes+2 length:length-2 separators:XADWindowsPathSeparator];
	else if(length>=1 && bytes[0]=='$') return [self XADPathWithBytes:bytes+1 length:length-1 separators:XADWindowsPathSeparator];
	else return [self XADPathWithData:data separators:XADWindowsPathSeparator];
}



-(CSHandle *)handleForBlockAtOffset:(off_t)offs
{
	return [self handleForBlockAtOffset:offs length:CSHandleMaxLength];
}

-(CSHandle *)handleForBlockAtOffset:(off_t)offs length:(off_t)length
{
	CSHandle *fh=[self handle];
	[fh seekToFileOffset:offs+base];
	uint32_t len=[fh readUInt32LE];
	CSHandle *sub=[fh nonCopiedSubHandleOfLength:len&0x7fffffff];
	if((len&0x80000000))
	{
		uint8_t head[2];
		[fh readBytes:2 toBuffer:head];
		[fh skipBytes:-2];
		if(head[0]==0x78&&head[1]==0xda)
		{
			CSZlibHandle *handle=[CSZlibHandle zlibHandleWithHandle:sub length:length];
			[handle setEndStreamAtInputEOF:YES];
			return handle;
		}
		else return [[[XADDeflateHandle alloc] initWithHandle:sub length:length variant:XADNSISDeflateVariant] autorelease];
	}
	else return sub;
}




-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum
{
	return [self handleForBlockAtOffset:[[dict objectForKey:@"NSISDataOffset"] unsignedIntValue]];
}

-(NSString *)formatName { return @"Old NSIS"; }

@end


static int IndexOfLargestEntry(const int *entries,int num)
{
	int max=INT_MIN,index=0;
	for(int i=0;i<num;i++)
	{
		if(entries[i]>max)
		{
			max=entries[i];
			index=i;
		}
	}
	return index;
}
