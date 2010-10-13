#import "XADARCParser.h"
#import "XADRLE90Handle.h"
#import "XADCompressHandle.h"
#import "XADCRCHandle.h"
#import "NSDateXAD.h"

@implementation XADARCParser

+(int)requiredHeaderSize { return 0x1d; }

+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name
{
	const uint8_t *bytes=[data bytes];
	int length=[data length];

	if(length<0x1d) return NO;

	// Check ID.
	if(bytes[0x00]!=0x1a) return NO;

	// Check file name.
	if(bytes[0x02]==0) return NO;
	for(int i=0x02;i<0x0f && bytes[i]!=0;i++)
	if((bytes[i]&0x7f)<32) return NO;

	// Check sizes.
	uint32_t compsize=CSUInt32LE(&bytes[0x0f]);
	uint32_t uncompsize=CSUInt32LE(&bytes[0x19]);
	if(compsize>0x1000000) return NO; // Assume files are less than 16 megabytes.
	if(compsize>uncompsize) return NO; // Assume files are always compressed or stored.

	// Check next file, if it fits in the buffer.
	// TODO: handle archimedes
	if(length>=0x1d+compsize+1)
	if(bytes[0x1d+compsize]!=0x1a) return NO;

	return YES;
}

-(void)parse
{
	CSHandle *fh=[self handle];

	for(;;)
	{
		int magic=[fh readUInt8];
		if(magic!=0x1a) [XADException raiseIllegalDataException];

		int method=[fh readUInt8];
		if(method==0x00) break;

		uint8_t namebuf[13];
		[fh readBytes:13 toBuffer:namebuf];

		int namelength=0;
		while(namelength<12 && namebuf[namelength]!=0) namelength++;
		if(namelength>1 && namebuf[namelength-1]==' ') namelength--;
		if(namelength>1 && namebuf[namelength-1]=='.') namelength--;
		NSData *namedata=[NSData dataWithBytes:namebuf length:namelength];

		uint32_t compsize=[fh readUInt32LE];
		uint32_t datetime=[fh readUInt32LE];
//		int time=[fh readUInt16LE];
		int crc16=[fh readUInt16LE];
		uint32_t uncompsize=[fh readUInt32LE];

		off_t dataoffset=[fh offsetInFile];

		XADString *name=[self XADStringWithData:namedata];
		XADPath *parent=[self XADPath];
		XADPath *path=[parent pathByAppendingPathComponent:name];

		NSMutableDictionary *dict=[NSMutableDictionary dictionaryWithObjectsAndKeys:
			path,XADFileNameKey,
			[NSNumber numberWithUnsignedLong:uncompsize],XADFileSizeKey,
			[NSNumber numberWithUnsignedLong:compsize],XADCompressedSizeKey,
			[NSNumber numberWithUnsignedLongLong:dataoffset],XADDataOffsetKey,
			[NSNumber numberWithUnsignedLong:compsize],XADDataLengthKey,
			[NSDate XADDateWithMSDOSDateTime:datetime],XADLastModificationDateKey,
			[NSNumber numberWithInt:method],@"ARCMethod",
			[NSNumber numberWithInt:crc16],@"ARCCRC16",
		nil];

		NSString *methodname=nil;
		switch(method)
		{
			case 0x01: methodname=@"None (old)"; break;
			case 0x02: methodname=@"None"; break;
			case 0x03: methodname=@"Packed"; break;
			case 0x04: methodname=@"Squeezed+packed"; break;
			case 0x05: methodname=@"Crunched"; break;
			case 0x06: methodname=@"Crunched+packed"; break;
			case 0x07: methodname=@"Crunched+packed (fast)"; break;
			case 0x08: methodname=@"Crunched+packed (LZW)"; break;
			case 0x09: methodname=@"Squashed"; break;
			case 0x0a: methodname=@"Crushed"; break;
			case 0x0b: methodname=@"Distilled"; break;
			case 0x7f: methodname=@"Compressed"; break;
		}
		if(methodname) [dict setObject:[self XADStringWithString:methodname] forKey:XADCompressionNameKey];

		[self addEntryWithDictionary:dict];

		[fh seekToFileOffset:dataoffset+compsize];
	}
}

-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum
{
	CSHandle *handle=[self handleAtDataOffsetForDictionary:dict];
	int method=[[dict objectForKey:@"ARCMethod"] intValue];
	int crc=[[dict objectForKey:@"ARCCRC16"] intValue];
	uint32_t length=[[dict objectForKey:XADFileSizeKey] unsignedIntValue];

	switch(method)
	{
		case 0x01: // Stored (untested)
		case 0x02: // Stored
		break;

		case 0x03: // Packed
			handle=[[[XADRLE90Handle alloc] initWithHandle:handle
			length:length] autorelease];
		break;

		case 0x04: // Squeezed+packed
			handle=[[[XADARCSqueezeHandle alloc] initWithHandle:handle] autorelease];

			handle=[[[XADRLE90Handle alloc] initWithHandle:handle
			length:length] autorelease];
		break;

		case 0x05: // Crunched
			handle=[[[XADARCCrunchHandle alloc] initWithHandle:handle
			length:length fast:NO] autorelease];
		break;

		case 0x06: // Crunched+packed
			handle=[[[XADARCCrunchHandle alloc] initWithHandle:handle fast:NO] autorelease];

			handle=[[[XADRLE90Handle alloc] initWithHandle:handle
			length:length] autorelease];
		break;

		case 0x07: // Crunched+packed (fast)
			handle=[[[XADARCCrunchHandle alloc] initWithHandle:handle fast:YES] autorelease];

			handle=[[[XADRLE90Handle alloc] initWithHandle:handle
			length:length] autorelease];
		break;

		case 0x08: // Crunched+packed (LZW)
		{
			int byte=[handle readUInt8];
			if(byte!=0x0c) [XADException raiseIllegalDataException];

			handle=[[[XADCompressHandle alloc] initWithHandle:handle
			flags:0x8c] autorelease];

			handle=[[[XADRLE90Handle alloc] initWithHandle:handle
			length:length] autorelease];
		}
		break;

		case 0x09: // Squashed
			handle=[[[XADCompressHandle alloc] initWithHandle:handle
			length:length flags:0x8d] autorelease];
		break;

		case 0x7f: // Compressed (untested)
		{
			int byte=[handle readUInt8];

			handle=[[[XADCompressHandle alloc] initWithHandle:handle
			length:length flags:byte|0x80] autorelease];
		}
		break;

		default: return nil;
	}

	if(checksum) handle=[XADCRCHandle IBMCRC16HandleWithHandle:handle length:length correctCRC:crc conditioned:NO];

	return handle;
}

-(NSString *)formatName { return @"ARC"; }

@end




@implementation XADARCSqueezeHandle

-(void)resetByteStream
{
	int numnodes=CSInputNextUInt16LE(input)*2;

	if(numnodes>=257*2) [XADException raiseDecrunchException];

	nodes[0]=nodes[1]=-(256+1);

	for(int i=0;i<numnodes;i++) nodes[i]=CSInputNextInt16LE(input);
	//if(nodes[i]>) [XADException raiseDecrunchException];
}

-(uint8_t)produceByteAtOffset:(off_t)pos
{
	int val=0;
	while(val>=0) val=nodes[2*val+CSInputNextBitLE(input)];

	int output=-(val+1);

	if(output==256) CSByteStreamEOF(self);

	return output;
}

@end






@implementation XADARCCrushHandle

-(void)initWithHandle:(CSHandle *)handle useFastHash:(BOOL)usefast
{
	return [self initWithHandle:handle length:CSHandleMaxLength useFastHash:usefast];
}

-(void)initWithHandle:(CSHandle *)handle length:(off_t)length useFastHash:(BOOL)usefast
{
	if(self=[super initWithHandle:handle length:length])
	{
		fast=usefast;
	}
	return self;
}


-(void)resetByteStream
{
    sp=0;
    numfreecodes=4096-256;

	for(int i=0;i<256;i++) [self updateTableWithParent:-1 byteValue:i];

/*    oldcode = xadIOGetBitsHigh(io,12);
    finchar = ad->string_tab[oldcode].follower;
    xadIOPutChar(io, finchar);*/

	lastcode=ARCNO_PRED;
}

-(uint8_t)produceByteAtOffset:(off_t)pos
{
	if(!sp)
	{
		int code=CSInputNextBitString(input,12);

		entry=&string_tab[code];

		if(!entry->used) /* if code isn't known */
		{
			entry=&string_tab[lastcode];
			stack[sp++]=finchar;
		}

		while(entry->parent!=-1)
		{
			if(sp>=4095) [XADException raiseDecrunchException];

			stack[sp++]=entry->byte;
			entry=&ad->string_tab[entry->parent];
		}

		stack[sp++]=finchar=ep->follower;

		if(numfreecodes!=0)
		{
			[self updateTableWithParent:lastcode byteValue:finchar];
			numfreecodes--;
		}

		lastcode=code;
	}

	return stack[--sp];
}

-(void)updateTableWithParent:(int)parent byteValue:(int)byte
{
	int local;
	if(fast) local=(((parent+byte)&0xffff)*15073)&0xfff;
	else
	{
		local=(parent+byte)|0x0800;
		local=(local*local>>6)&0xfff;
	}

	if(string_tab[local].used) /* a collision has occured */
	{
		while(ad->string_tab[local].next)      /* while more duplicates */
 		local=ad->string_tab[local].next;

		/* We must find an empty spot. We start looking 101 places down the table from the last duplicate. */
		next=(local+101)&0xfff;

		while(string_tab[next]->used) next=(next+1)&0xfff;

		/* local still has the pointer to the last duplicate, while
		* tempnext has the pointer to the spot we found.  We use
		* this to maintain the chain of pointers to duplicates. */
		string_tab[local].next=next;

		local=next;
	}

	string_tab[local]->used=YES;
	string_tab[local]->next=0;
	string_tab[local]->parent=parent;
	string_tab[local]->byte=byte;
}


@end


