#import "XADCrunchParser.h"
#import "XADCrunchHandles.h"
#import "XADRLE90Handle.h"
#import "XADChecksumHandle.h"
#import "NSDateXAD.h"

BOOL IsCrunchHeader(const uint8_t *bytes,int length)
{
	if(length<9) return NO;

	if(bytes[0]!=0x76 || (bytes[1]!=0xfe && bytes[1]!=0xfd)) return NO;

	if(bytes[2]==0) return NO;
	for(int i=2;i<length;i++)
	{
		if(bytes[i]==0)
		{
			if(i+4>length) return NO;
			if(bytes[i+1]<0x10||bytes[i+1]>0x2f) return NO;
			if(bytes[i+2]<0x10||bytes[i+2]>0x2f) return NO;
			return YES;
		}
		//if(bytes[i]<32) return NO;
	}

	return NO;
}

@implementation XADCrunchParser

+(int)requiredHeaderSize { return 1024; }

+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name
{
	return IsCrunchHeader([data bytes],[data length]);
}

-(void)parse
{
	CSHandle *fh=[self handle];

	[fh skipBytes:1];
	int type=[fh readUInt8];

	NSMutableData *data=[NSMutableData data];
	uint8_t byte;
	while((byte=[fh readUInt8])) [data appendBytes:&byte length:1];

	const char *bytes=[data bytes];
	int length=[data length];

	NSData *namepart=data;
	NSData *comment=nil;
	int namelength=length;
	for(int i=0;i<length;i++)
	{
		if(bytes[i]=='.')
		{
			namelength=i+4;
			if(namelength>length||bytes[namelength-1]==' ') namelength--;
			if(namelength>length||bytes[namelength-1]==' ') namelength--;
			if(namelength>length||bytes[namelength-1]==' ') namelength--;

			namepart=[data subdataWithRange:NSMakeRange(0,namelength)];

			if(i+7<length && bytes[i+4]==' ' && bytes[i+5]=='[' && bytes[length-1]==']')
			comment=[data subdataWithRange:NSMakeRange(i+6,length-i-7)];

			break;
		}
	}

	int version1=[fh readUInt8];
	int version2=[fh readUInt8];
	int errordetection=[fh readUInt8];
	[fh skipBytes:1];

	NSString *compname;
	BOOL old=(version2&0xf0)==0x10;
	if(type==0xfe)
	{
		if(old) compname=@"LZW 1.0";
		else compname=@"LZW 2.0";
	}
	else
	{
		if(old) compname=@"LZHUF 1.0";
		else compname=@"LZHUF 2.0";
	}

	off_t dataoffset=[fh offsetInFile];
	off_t filesize=[fh fileSize];

	NSMutableDictionary *dict=[NSMutableDictionary dictionaryWithObjectsAndKeys:
		[self XADPathWithData:namepart separators:XADNoPathSeparator],XADFileNameKey,
		[self XADStringWithString:compname],XADCompressionNameKey,
		[NSNumber numberWithLongLong:filesize-dataoffset],XADCompressedSizeKey,
		[NSNumber numberWithUnsignedLongLong:dataoffset],XADDataOffsetKey,
		[NSNumber numberWithLongLong:filesize-dataoffset],XADDataLengthKey,
		[NSNumber numberWithInt:type],@"CrunchType",
		[NSNumber numberWithInt:version1],@"CrunchReferenceRevision",
		[NSNumber numberWithInt:version2],@"CrunchSignificantRevision",
		[NSNumber numberWithInt:errordetection],@"CrunchErrorDetection",
	nil];

	if(comment) [dict setObject:[self XADStringWithData:comment] forKey:XADCommentKey];

	if(namelength>4)
	if(bytes[namelength-4]=='.')
	if(tolower(bytes[namelength-3])=='l')
	if(tolower(bytes[namelength-2])=='b')
	if(tolower(bytes[namelength-1])=='r')
	{
		[dict setObject:[NSNumber numberWithBool:YES] forKey:XADIsArchiveKey];
	}

	[self addEntryWithDictionary:dict];
}

-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum
{
	CSHandle *handle=[self handleAtDataOffsetForDictionary:dict];
	int type=[[dict objectForKey:@"CrunchType"] intValue];
	int version2=[[dict objectForKey:@"CrunchSignificantRevision"] intValue];
	int errordetection=[[dict objectForKey:@"CrunchErrorDetection"] intValue];
	BOOL old=(version2&0xf0)==0x10;
	BOOL haschecksum=errordetection==0;

	if(type==0xfe) handle=[[[XADCrunchZHandle alloc] initWithHandle:handle old:old hasChecksum:haschecksum] autorelease];
	else handle=[[[XADCrunchYHandle alloc] initWithHandle:handle old:old hasChecksum:haschecksum] autorelease];

	return handle;
}

-(NSString *)formatName { return @"Crunch"; }

@end




