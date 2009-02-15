#import "XADMacArchiveParser.h"
#import "NSDateXAD.h"

NSString *XADIsMacBinaryKey=@"XADIsMacBinary";
NSString *XADDisableMacForkExpansionKey=@"XADDisableMacForkExpansionKey";

@implementation XADMacArchiveParser

-(id)initWithHandle:(CSHandle *)handle name:(NSString *)name;
{
	if(self=[super initWithHandle:handle name:name])
	{
		currhandle=nil;
		dittoregex=[[XADRegex alloc] initWithPattern:@"(^__MACOSX/|^)((.*/)\\._|\\._)([^/]+)$" options:0];
	}
	return self;
}

-(void)dealloc
{
	[dittoregex release];
	[super dealloc];
}

-(void)addEntryWithDictionary:(NSMutableDictionary *)dict retainPosition:(BOOL)retainpos
{
	[self addEntryWithDictionary:dict retainPosition:retainpos checkForMacBinary:NO];
}

-(void)addEntryWithDictionary:(NSMutableDictionary *)dict checkForMacBinary:(BOOL)checkbin
{
	[self addEntryWithDictionary:dict retainPosition:NO checkForMacBinary:checkbin];
}

-(void)addEntryWithDictionary:(NSMutableDictionary *)dict retainPosition:(BOOL)retainpos checkForMacBinary:(BOOL)checkbin
{
	if(retainpos) [XADException raiseNotSupportedException];

	// Check if expansion of forks is disabled
	NSNumber *disable=[properties objectForKey:XADDisableMacForkExpansionKey];
	if(disable&&[disable boolValue])
	{
		NSNumber *isbin=[dict objectForKey:XADIsMacBinaryKey];
		if(isbin&&[isbin boolValue]) [dict setObject:[NSNumber numberWithBool:YES] forKey:XADIsArchiveKey];

		[super addEntryWithDictionary:dict retainPosition:retainpos];
		return;
	}

	NSString *name=[[dict objectForKey:XADFileNameKey] string];
	NSNumber *isdir=[dict objectForKey:XADIsDirectoryKey];

	// Handle directories - only needs to check for useless ditto directories
	if(isdir&&[isdir boolValue])
	{
		if(![name hasPrefix:@"__MACOSX/"]) // Discard directories used for ditto forks
		[super addEntryWithDictionary:dict retainPosition:retainpos];
		return;
	}

	// Check if the file is a ditto fork
	if([self parseAppleDoubleWithDictionary:dict name:name]) return;

	// Check for MacBinary files
	if([self parseMacBinaryWithDictionary:dict name:name checkContents:checkbin]) return;

	// Nothing else worked, it's a normal file
	[super addEntryWithDictionary:dict retainPosition:retainpos];
}

-(BOOL)parseAppleDoubleWithDictionary:(NSMutableDictionary *)dict name:(NSString *)name
{
	if(!name) return NO;

	NSArray *matches=[dittoregex capturedSubstringsOfString:name];
	if(!matches) return NO;

	NSString *origname=[[matches objectAtIndex:3] stringByAppendingString:[matches objectAtIndex:4]];
	uint32_t rsrcoffs=0,rsrclen=0;
	uint32_t finderoffs=0,finderlen=0;
	NSData *finderinfo=nil;
	CSHandle *fh=[self rawHandleForEntryWithDictionary:dict wantChecksum:YES];

	@try
	{
		if([fh readUInt32BE]!=0x00051607) return NO;
		if([fh readUInt32BE]!=0x00020000) return NO;
		[fh skipBytes:16];
		int num=[fh readUInt16BE];

		for(int i=0;i<num;i++)
		{
			uint32_t entryid=[fh readUInt32BE];
			uint32_t entryoffs=[fh readUInt32BE];
			uint32_t entrylen=[fh readUInt32BE];

			switch(entryid)
			{
				case 2: // resource fork
					rsrcoffs=entryoffs;
					rsrclen=entrylen;
				break;
				case 9: // finder
					finderoffs=entryoffs;
					finderlen=entrylen;
				break;
			}
		}

		if(finderoffs)
		{
			[fh seekToFileOffset:finderoffs];
			finderinfo=[fh readDataOfLength:finderlen];
		}
	}
	@catch(id e)
	{
		return NO;
	}

	if(!rsrcoffs) return NO;

	NSMutableDictionary *newdict=[NSMutableDictionary dictionaryWithDictionary:dict];

	[newdict setObject:dict forKey:@"MacOriginalDictionary"];
	[newdict setObject:[NSNumber numberWithUnsignedInt:rsrcoffs] forKey:@"MacDataOffset"];
	[newdict setObject:[NSNumber numberWithUnsignedInt:rsrclen] forKey:@"MacDataLength"];
	[newdict setObject:[NSNumber numberWithUnsignedInt:rsrclen] forKey:XADFileSizeKey];
	[newdict setObject:[NSNumber numberWithBool:YES] forKey:XADIsResourceForkKey];
	[newdict setObject:[self XADStringWithString:origname] forKey:XADFileNameKey];
	if(finderinfo) [newdict setObject:finderinfo forKey:XADFinderInfoKey];

	[newdict removeObjectForKey:XADDataLengthKey];
	[newdict removeObjectForKey:XADDataOffsetKey];

	currhandle=fh;
	[super addEntryWithDictionary:newdict retainPosition:NO];
	currhandle=nil;

	return YES;
}

-(BOOL)parseMacBinaryWithDictionary:(NSMutableDictionary *)dict name:(NSString *)name checkContents:(BOOL)check
{
	if(!name) return NO;

	NSNumber *isbinobj=[dict objectForKey:XADIsMacBinaryKey];
	BOOL isbin=isbinobj?[isbinobj boolValue]:NO;

	if(!isbin)
	{
		if(!check) return NO;
		if(![name hasSuffix:@".bin"]) return NO;
	}

	CSHandle *fh=[self rawHandleForEntryWithDictionary:dict wantChecksum:YES];

	NSData *header=[fh readDataOfLengthAtMost:128];
	if([header length]!=128) return NO;

	const uint8_t *bytes=[header bytes];

	// Only accept MacBinary III files
	if(CSUInt32BE(bytes+102)!='mBIN') return NO;
	if(XADCalculateCRC(0,bytes,124,XADCRCReverseTable_1021)!=XADUnReverseCRC16(CSUInt16BE(bytes+124))) return NO;
	if(bytes[1]>63) return NO;

	uint32_t datasize=CSUInt32BE(bytes+83);
	uint32_t rsrcsize=CSUInt32BE(bytes+87);
	int extsize=CSUInt16BE(bytes+120);
	off_t compsize=[[dict objectForKey:XADCompressedSizeKey] longLongValue];

	NSMutableDictionary *template=[NSMutableDictionary dictionaryWithDictionary:dict];
	[template setObject:dict forKey:@"MacOriginalDictionary"];
	[template setObject:[self XADStringWithBytes:bytes+2 length:bytes[1]] forKey:XADFileNameKey];
	[template setObject:[NSNumber numberWithUnsignedInt:CSUInt32BE(bytes+65)] forKey:XADFileTypeKey];
	[template setObject:[NSNumber numberWithUnsignedInt:CSUInt32BE(bytes+69)] forKey:XADFileCreatorKey];
	[template setObject:[NSNumber numberWithInt:bytes[73]+(bytes[101]<<8)] forKey:XADFinderFlagsKey];
	[template setObject:[NSNumber numberWithUnsignedInt:CSUInt32BE(bytes+65)] forKey:XADFileTypeKey];
	[template setObject:[NSDate XADDateWithTimeIntervalSince1904:CSUInt32BE(bytes+91)] forKey:XADCreationDateKey];
	[template setObject:[NSDate XADDateWithTimeIntervalSince1904:CSUInt32BE(bytes+95)] forKey:XADLastModificationDateKey];
	[template removeObjectForKey:XADDataLengthKey];
	[template removeObjectForKey:XADDataOffsetKey];

	currhandle=fh;

	#define BlockSize(size) (((size)+127)&~127)
	if(datasize||!rsrcsize)
	{
		NSMutableDictionary *newdict=[NSMutableDictionary dictionaryWithDictionary:template];
		[newdict setObject:[NSNumber numberWithUnsignedInt:128+BlockSize(extsize)] forKey:@"MacDataOffset"];
		[newdict setObject:[NSNumber numberWithUnsignedInt:datasize] forKey:@"MacDataLength"];
		[newdict setObject:[NSNumber numberWithUnsignedInt:datasize] forKey:XADFileSizeKey];
		[newdict setObject:[NSNumber numberWithUnsignedInt:compsize*(datasize+1)/(datasize+rsrcsize+2)] forKey:XADCompressedSizeKey];

		[super addEntryWithDictionary:newdict retainPosition:NO];
	}

	if(rsrcsize)
	{
		NSMutableDictionary *newdict=[NSMutableDictionary dictionaryWithDictionary:template];
		[newdict setObject:[NSNumber numberWithUnsignedInt:128+BlockSize(extsize)+BlockSize(datasize)] forKey:@"MacDataOffset"];
		[newdict setObject:[NSNumber numberWithUnsignedInt:rsrcsize] forKey:@"MacDataLength"];
		[newdict setObject:[NSNumber numberWithUnsignedInt:rsrcsize] forKey:XADFileSizeKey];
		[newdict setObject:[NSNumber numberWithUnsignedInt:compsize*(rsrcsize+1)/(datasize+rsrcsize+2)] forKey:XADCompressedSizeKey];
		[newdict setObject:[NSNumber numberWithBool:YES] forKey:XADIsResourceForkKey];

		[super addEntryWithDictionary:newdict retainPosition:NO];
	}

	currhandle=nil;

	return YES;
}



-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum
{
	NSDictionary *origdict=[dict objectForKey:@"MacOriginalDictionary"];
	if(origdict)
	{
		off_t offset=[[dict objectForKey:@"MacDataOffset"] longLongValue];
		off_t length=[[dict objectForKey:@"MacDataLength"] longLongValue];

		CSHandle *handle;
		if(currhandle) handle=currhandle;
		else handle=[self rawHandleForEntryWithDictionary:origdict wantChecksum:checksum];

		return [handle nonCopiedSubHandleFrom:offset length:length];
	}

	return [self rawHandleForEntryWithDictionary:dict wantChecksum:checksum];
}



-(CSHandle *)rawHandleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum
{
	return nil;
}

@end
