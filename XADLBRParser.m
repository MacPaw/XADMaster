#import "XADLBRParser.h"
#import "XADCRCHandle.h"
#import "NSDateXAD.h"

@implementation XADLBRParser

+(int)requiredHeaderSize { return 128; }

+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name
{
	const uint8_t *bytes=[data bytes];
	int length=[data length];

	if(length<128) return NO;

	if(bytes[0]!=0) return NO;

	for(int i=1;i<12;i++) if(bytes[i]!=' ') return NO;

	if(bytes[12]!=0) return NO;
	if(bytes[13]!=0) return NO;

	for(int i=26;i<32;i++) if(bytes[i]!=0) return NO;

	int sectors=CSUInt16LE(&bytes[14]);
	if(sectors==0) return NO;

	// Check CRC if it exists, and there is enough data to do so.
	int correctcrc=CSUInt16LE(&bytes[16]);
	int size=sectors*128;
	if(correctcrc && size<=length)
	{
		int crc=0;
		crc=XADCalculateCRC(crc,&bytes[0],16,XADCRCReverseTable_1021);
		crc=XADCRC(crc,0,XADCRCReverseTable_1021);
		crc=XADCRC(crc,0,XADCRCReverseTable_1021);
		crc=XADCalculateCRC(crc,&bytes[18],size-18,XADCRCReverseTable_1021);
		if(XADUnReverseCRC16(crc)!=correctcrc) return NO;
	}

	return YES;
}

-(void)parse
{
	CSHandle *fh=[self handle];

	[fh skipBytes:14];
	int numsectors=[fh readUInt16LE];
	int numentries=numsectors*4-1;
	[fh skipBytes:16];

	for(int i=0;i<numentries;i++)
	{
		int status=[fh readUInt8];
		if(status!=0)
		{
			[fh skipBytes:31];
			continue;
		}

		uint8_t namebuf[11];
		[fh readBytes:11 toBuffer:namebuf];

		NSMutableData *data=[NSMutableData data];

		int namelength=8;
		while(namelength>1 && namebuf[namelength-1]==' ') namelength--;
		[data appendBytes:&namebuf[0] length:namelength];

		[data appendBytes:(uint8_t []){'.'} length:1];

		int extlength=3;
		while(extlength>1 && namebuf[extlength+8]==' ') extlength--;
		[data appendBytes:&namebuf[8] length:extlength];

		int index=[fh readUInt16LE];
		int length=[fh readUInt16LE];
		int crc=[fh readUInt16LE];

		int creationdate=[fh readUInt16LE];
		int modificationdate=[fh readUInt16LE];
		int creationtime=[fh readUInt16LE];
		int modificationtime=[fh readUInt16LE];
		int padding=[fh readUInt8];

		if(!modificationdate)
		{
			modificationdate=creationdate;
			modificationtime=creationtime;
		}

		[fh skipBytes:5];

		NSMutableDictionary *dict=[NSMutableDictionary dictionaryWithObjectsAndKeys:
			[self XADPathWithData:data separators:XADNoPathSeparator],XADFileNameKey,
			[NSNumber numberWithLongLong:length*128-padding],XADFileSizeKey,
			[NSNumber numberWithLongLong:length*128],XADCompressedSizeKey,
			[NSNumber numberWithLongLong:length*128-padding],XADDataLengthKey,
			[NSNumber numberWithLongLong:index*128],XADDataOffsetKey,
			[NSNumber numberWithInt:crc],@"LBRCRC16",
		nil];

		if(creationdate)
		[dict setObject:[NSDate XADDateWithCPMDate:creationdate
		time:creationtime] forKey:XADCreationDateKey];

		if(modificationdate)
		[dict setObject:[NSDate XADDateWithCPMDate:modificationdate
		time:modificationtime] forKey:XADLastModificationDateKey];


		[self addEntryWithDictionary:dict retainPosition:YES];
	}
}

-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum
{
	CSHandle *handle=[self handleAtDataOffsetForDictionary:dict];
	uint32_t length=[[dict objectForKey:XADDataLengthKey] intValue];
	NSNumber *crc=[dict objectForKey:@"LBRCRC16"];

	if(checksum&&crc) handle=[XADCRCHandle CCITTCRC16HandleWithHandle:handle
	length:length correctCRC:[crc intValue] conditioned:NO];

	return handle;
}

-(NSString *)formatName { return @"LBR"; }

@end




