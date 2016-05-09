#import "XADRARInputHandle.h"
#import "XADException.h"
#import "CRC.h"

@implementation XADRARInputHandle

-(id)initWithHandle:(CSHandle *)handle parts:(NSArray *)partarray
{
	off_t totallength=0;
	NSEnumerator *enumerator=[partarray objectEnumerator];
	NSDictionary *dict;
	while((dict=[enumerator nextObject]))
	{
		totallength+=[[dict objectForKey:@"InputLength"] longLongValue];
	}

	if((self=[super initWithParentHandle:handle length:totallength]))
	{
		parts=[partarray retain];
	}
	return self;
}

-(void)dealloc
{
	[parts release];
	[super dealloc];
}

-(void)resetStream
{
	part=0;
	partend=0;

	[self startNextPart];
}

-(int)streamAtMost:(int)num toBuffer:(void *)buffer
{
	uint8_t *bytebuf=buffer;
	int total=0;
	while(total<num)
	{
		if(streampos+total>=partend) [self startNextPart];

		int numbytes=num-total;
		if(streampos+total+numbytes>=partend) numbytes=(int)(partend-streampos-total);

		[parent readBytes:numbytes toBuffer:&bytebuf[total]];

		crc=XADCalculateCRC(crc,&bytebuf[total],numbytes,XADCRCTable_edb88320);

		total+=numbytes;

		// RAR CRCs are for compressed and encrypted data for all parts
		// except the last one, where it is for descrypted and uncompressed data.
		// Check the CRC on all parts but the last.
		// TODO: Add blake2sp
		if(streampos+total>=partend) // If at the end a block,
		if(partend!=streamlength) // but not the end of the file,
		if(correctcrc!=0xffffffff) // and there is a correct CRC available,
		if(~crc!=correctcrc) [XADException raiseChecksumException]; // check it.
	}

	return num;
}

-(void)startNextPart
{
	if(part>=[parts count]) [XADException raiseInputException];
	NSDictionary *dict=[parts objectAtIndex:part];
	part++;

	off_t offset=[[dict objectForKey:@"Offset"] longLongValue];
	off_t length=[[dict objectForKey:@"InputLength"] longLongValue];

	[parent seekToFileOffset:offset];
	partend+=length;

	crc=0xffffffff;
	NSNumber *crcnum=[dict objectForKey:@"CRC32"];
	if(crcnum) correctcrc=[crcnum unsignedIntValue];
	else correctcrc=0xffffffff;
}

@end

