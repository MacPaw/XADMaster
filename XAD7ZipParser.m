#import "XAD7ZipParser.h"
#import "XADLZMAHandle.h"
#import "XADDeflateHandle.h"
#import "CSZlibHandle.h"
#import "CSBzip2Handle.h"
#import "Checksums.h"
#import "NSDateXAD.h"

static uint64_t ReadNumber(CSHandle *handle)
{
	int first=[handle readUInt8];
	uint64_t val=0;

	for(int i=0;i<8;i++)
	{
		if((first&(0x80>>i))==0) return val|((first&((0x80>>i)-1))<<i*8);
		val|=(uint64_t)[handle readUInt8]<<i*8;
	}
	return val;
}

static NSMutableArray *ArrayWithLength(int length)
{
	NSMutableArray *array=[NSMutableArray arrayWithCapacity:length];
	for(int i=0;i<length;i++) [array addObject:[NSMutableDictionary dictionary]];
	return array;
}

static inline void SetObjectEntryInArray(NSArray *array,int index,id obj,NSString *key)
{
	NSMutableDictionary *dict=[array objectAtIndex:index];
	if(obj) [dict setObject:obj forKey:key];
	else [dict removeObjectForKey:key];
}

static inline void SetNumberEntryInArray(NSArray *array,int index,uint64_t value,NSString *key)
{
	[[array objectAtIndex:index] setObject:[NSNumber numberWithUnsignedLongLong:value] forKey:key];
}

static inline void SkipEntry(CSHandle *handle) { [handle skipBytes:ReadNumber(handle)]; }

static void FindAttribute(CSHandle *handle,int attribute)
{
	for(;;)
	{
		uint64_t type=ReadNumber(handle);
		if(type==attribute) return;
		else if(type==0) [XADException raiseIllegalDataException];
		SkipEntry(handle);
	}
}



@implementation XAD7ZipParser

+(int)requiredHeaderSize { return 32; }

+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name
{
	const uint8_t *bytes=[data bytes];
	int length=[data length];

	return length>=32&&bytes[0]=='7'&&bytes[1]=='z'&&bytes[2]==0xbc&&bytes[3]==0xaf
	&&bytes[4]==0x27&&bytes[5]==0x1c&&bytes[6]==0;
}

+(XADRegex *)volumeRegexForFilename:(NSString *)filename
{
/*	NSArray *matches;
	if(matches=[filename substringsCapturedByPattern:@"^(.*)\\.(alz|a[0-9]{2}|b[0-9]{2})$" options:REG_ICASE])
	return [XADRegex regexWithPattern:[NSString stringWithFormat:
	@"^%@\\.(alz|a[0-9]{2}|b[0-9]{2})$",[[matches objectAtIndex:1] escapedPattern]] options:REG_ICASE];
*/
	return nil;
}

+(BOOL)isFirstVolume:(NSString *)filename
{
//	return [filename rangeOfString:@".alz" options:NSAnchoredSearch|NSCaseInsensitiveSearch|NSBackwardsSearch].location!=NSNotFound;
	return NO;
}

-(id)initWithHandle:(CSHandle *)handle name:(NSString *)name
{
	if(self=[super initWithHandle:handle name:name])
	{
		mainstreams=nil;
		currfolder=nil;
		currfolderhandle=nil;
	}
	return self;
}

-(void)dealloc
{
	[mainstreams release];
	[currfolder release];
	[currfolderhandle release];
	[super dealloc];
}

-(void)parse
{
	CSHandle *handle=[self handle];

	[handle skipBytes:12];

	off_t nextheaderoffs=[handle readUInt64LE];
	//off_t nextheadersize=[handle readUInt64LE];

	[handle seekToFileOffset:nextheaderoffs+32];

	CSHandle *fh=handle;

	for(;;)
	{
		int type=ReadNumber(fh);
		if(type==1) break; // Header
		else if(type==23) // EncodedHeader
		{
			NSDictionary *streams=[self parseStreamsForHandle:fh];
			fh=[self handleForStreams:streams substreamIndex:0 wantChecksum:NO];
		}
		else [XADException raiseIllegalDataException];
	}

	NSDictionary *additionalstreams=nil;
	NSArray *files=nil;

	for(;;)
	{
		int type=ReadNumber(fh);
		switch(type)
		{
			case 0: goto end;

			case 2: // ArchiveProperties
				for(;;)
				{
					uint64_t type=ReadNumber(fh);
					if(type==0) break;
					[fh skipBytes:ReadNumber(fh)];
				}
			break;

			case 3: // AdditionalStreamsInfo
				additionalstreams=[self parseStreamsForHandle:fh];
			break;

			case 4: // MainStreamsInfo
				mainstreams=[[self parseStreamsForHandle:fh] retain];
			break;

			case 5: // FilesInfo
				files=[self parseFilesForHandle:fh];
			break;
		}
	}

	end: 0;
	NSArray *substreams=[mainstreams objectForKey:@"SubStreams"];
	int currsubstream=0;

	int numfiles=[files count];
	for(int i=0;i<numfiles;i++)
	{
		NSMutableDictionary *file=[files objectAtIndex:i];

		if([file objectForKey:@"7zIsEmptyStream"])
		{
			if([file objectForKey:@"7zIsEmptyFile"]) 
			[file setObject:[NSNumber numberWithInt:0] forKey:XADFileSizeKey];
			else
			[file setObject:[NSNumber numberWithBool:YES] forKey:XADIsDirectoryKey];
		}
		else
		{
			NSDictionary *substream=[substreams objectAtIndex:currsubstream];
			[file setObject:[NSNumber numberWithInt:currsubstream] forKey:@"7zSubStreamIndex"];
			[file setObject:[substream objectForKey:@"Size"] forKey:XADFileSizeKey];
			currsubstream++;
		}

		if(![file objectForKey:@"7zIsAntiFile"]) [self addEntryWithDictionary:file];
	}
}

-(NSArray *)parseFilesForHandle:(CSHandle *)handle
{
	int numfiles=ReadNumber(handle);
	NSMutableArray *files=ArrayWithLength(numfiles);
	NSMutableArray *emptystreams=nil;

	for(;;)
	{
		int type=ReadNumber(handle);
		if(type==0) return files;

		uint64_t size=ReadNumber(handle);
		off_t next=[handle offsetInFile]+size;

		switch(type)
		{
			case 14: // EmptyStream
				[self parseBitVectorForHandle:handle array:files key:@"7zIsEmptyStream"];

				emptystreams=[NSMutableArray array];
				for(int i=0;i<numfiles;i++)
				if([[files objectAtIndex:i] objectForKey:@"7zIsEmptyStream"]) [emptystreams addObject:[files objectAtIndex:i]];
			break;

			case 15: // EmptyFile
				[self parseBitVectorForHandle:handle array:emptystreams key:@"7zIsEmptyFile"];
			break;

			case 16: // Anti
				[self parseBitVectorForHandle:handle array:emptystreams key:@"7zIsAntiFile"];
			break;

			case 17: // Names
				[self parseNamesForHandle:handle array:files];
			break;

			case 18: // CTime
				[self parseDatesForHandle:handle array:files key:XADCreationDateKey];
			break;

			case 19: // ATime
				[self parseDatesForHandle:handle array:files key:XADLastAccessDateKey];
			break;

			case 20: // MTime
				[self parseDatesForHandle:handle array:files key:XADLastModificationDateKey];
			break;

			case 21: // Attributes
				[self parseAttributesForHandle:handle array:files];
			break;

			case 22: // Comment
				NSLog(@"7z comment"); // TODO: do something with this
			break;

			case 24: // StartPos
				NSLog(@"7z startpos"); // TODO: do something with this
			break;
		}

		[handle seekToFileOffset:next];
	}
}

-(void)parseBitVectorForHandle:(CSHandle *)handle array:(NSArray *)array key:(NSString *)key
{
	NSNumber *yes=[NSNumber numberWithBool:YES];
	int num=[array count];
	int byte;
	for(int i=0;i<num;i++)
	{
		if(i%8==0) byte=[handle readUInt8];
		if(byte&(0x80>>i%8)) [[array objectAtIndex:i] setObject:yes forKey:key];
	}
}

-(NSIndexSet *)parseDefintionVectorForHandle:(CSHandle *)handle numberOfElements:(int)num
{
	if([handle readUInt8]) return [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0,num)];

	NSMutableIndexSet *indexes=[NSMutableIndexSet indexSet];
	int byte;
	for(int i=0;i<num;i++)
	{
		if(i%8==0) byte=[handle readUInt8];
		if(byte&(0x80>>i%8)) [indexes addIndex:i];
	}
	return indexes;
}

-(void)parseDatesForHandle:(CSHandle *)handle array:(NSMutableArray *)array key:(NSString *)key
{
	NSIndexSet *indexes=[self parseDefintionVectorForHandle:handle numberOfElements:[array count]];

	int external=[handle readUInt8];
	if(external!=0) [XADException raiseNotSupportedException]; // TODO: figure out what to do

	for(int i=[indexes firstIndex];i!=NSNotFound;i=[indexes indexGreaterThanIndex:i])
	{
		uint32_t low=[handle readUInt32LE];
		uint32_t high=[handle readUInt32LE];
		SetObjectEntryInArray(array,i,[NSDate XADDateWithWindowsFileTimeLow:low high:high],key);
	}
}

-(void)parseCRCsForHandle:(CSHandle *)handle array:(NSMutableArray *)array
{
	NSIndexSet *indexes=[self parseDefintionVectorForHandle:handle numberOfElements:[array count]];
	for(int i=[indexes firstIndex];i!=NSNotFound;i=[indexes indexGreaterThanIndex:i])
	SetNumberEntryInArray(array,i,[handle readUInt32LE],@"CRC");
}

-(void)parseNamesForHandle:(CSHandle *)handle array:(NSMutableArray *)array
{
	int external=[handle readUInt8];
	if(external!=0) [XADException raiseNotSupportedException]; // TODO: figure out what to do

	int numnames=[array count];
	for(int i=0;i<numnames;i++)
	{
		NSMutableString *name=[NSMutableString string];

		for(;;)
		{
			uint16_t c=[handle readUInt16LE];
			if(c==0) break;
			[name appendFormat:@"%C",c];
		}
		SetObjectEntryInArray(array,i,[self XADStringWithString:name],XADFileNameKey);
	}
}

-(void)parseAttributesForHandle:(CSHandle *)handle array:(NSMutableArray *)array
{
	NSIndexSet *indexes=[self parseDefintionVectorForHandle:handle numberOfElements:[array count]];

	int external=[handle readUInt8];
	if(external!=0) [XADException raiseNotSupportedException]; // TODO: figure out what to do

	for(int i=[indexes firstIndex];i!=NSNotFound;i=[indexes indexGreaterThanIndex:i])
	SetNumberEntryInArray(array,i,[handle readUInt32LE],XADWindowsFileAttributesKey);
}



-(NSDictionary *)parseStreamsForHandle:(CSHandle *)handle
{
	NSMutableDictionary *dict=[NSMutableDictionary dictionary];
	NSArray *folders=nil,*packedstreams=nil;
	for(;;)
	{
		int type=ReadNumber(handle);
		switch(type)
		{
			case 0: // End
				[dict setObject:[self collectAllSubStreamsFromFolders:folders] forKey:@"SubStreams"];
				return dict;

			case 6: // PackInfo
				packedstreams=[self parsePackedStreamsForHandle:handle];
				[dict setObject:packedstreams forKey:@"PackedStreams"];
			break;

			case 7: // CodersInfo
				folders=[self parseFoldersForHandle:handle packedStreams:packedstreams];
				[self setupDefaultSubStreamsForFolders:folders];
				[dict setObject:folders forKey:@"Folders"];
			break;

			case 8: // SubStreamsInfo
				[self parseSubStreamsInfoForHandle:handle folders:folders];
			break;

			default: [XADException raiseIllegalDataException];
		}
	}
	return nil; // can't happen
}

-(NSArray *)parsePackedStreamsForHandle:(CSHandle *)handle
{
	uint64_t dataoffset=ReadNumber(handle)+32;
	int numpackedstreams=ReadNumber(handle);
	NSMutableArray *packedstreams=ArrayWithLength(numpackedstreams);

	for(;;)
	{
		int type=ReadNumber(handle);
		switch(type)
		{
			case 0: return packedstreams;

			case 9: // Size
			{
				uint64_t total=0;
				for(int i=0;i<numpackedstreams;i++)
				{
					uint64_t size=ReadNumber(handle);
					SetNumberEntryInArray(packedstreams,i,size,@"Size");
					SetNumberEntryInArray(packedstreams,i,dataoffset+total,@"Offset");
					total+=size;
				}
			}
			break;

			case 10: // CRC
				[self parseCRCsForHandle:handle array:packedstreams];
			break;

			default: SkipEntry(handle); break;
		}
	}
	return nil; // can't happen
}

-(NSArray *)parseFoldersForHandle:(CSHandle *)handle packedStreams:(NSArray *)packedstreams
{
	FindAttribute(handle,11); // Folder

	int numfolders=ReadNumber(handle);
	NSMutableArray *folders=ArrayWithLength(numfolders);

	int external=[handle readUInt8];
	if(external!=0) [XADException raiseNotSupportedException]; // TODO: figure out how the hell to handle this

	int packedstreamindex=0;
	for(int i=0;i<numfolders;i++)
	[self parseFolderForHandle:handle dictionary:[folders objectAtIndex:i]
	packedStreams:packedstreams packedStreamIndex:&packedstreamindex];

	for(;;)
	{
		int type=ReadNumber(handle);
		switch(type)
		{
			case 0: return folders;

			case 12: // CodersUnpackSize
				for(int i=0;i<numfolders;i++)
				{
					NSArray *outstreams=[[folders objectAtIndex:i] objectForKey:@"OutStreams"];
					int numoutstreams=[outstreams count];
					for(int j=0;j<numoutstreams;j++)
					SetNumberEntryInArray(outstreams,j,ReadNumber(handle),@"Size");
				}
			break;

			case 10: // CRC
				[self parseCRCsForHandle:handle array:folders];
			break;

			default: SkipEntry(handle); break;
		}
	}

	return nil; // can't happen
}

-(void)parseFolderForHandle:(CSHandle *)handle dictionary:(NSMutableDictionary *)dictionary
packedStreams:(NSArray *)packedstreams packedStreamIndex:(int *)packedstreamindex
{
	int numcoders=ReadNumber(handle);
	NSMutableArray *instreams=[NSMutableArray array];
	NSMutableArray *outstreams=[NSMutableArray array];

	// Load coders
	for(int i=0;i<numcoders;i++)
	{
		int flags=[handle readUInt8];
		NSData *coderid=[handle readDataOfLength:flags&0x0f];

		int numinstreams=0,numoutstreams=0;
		if(flags&0x10)
		{
			numinstreams=ReadNumber(handle);
			numoutstreams=ReadNumber(handle);
		}
		else numoutstreams=numinstreams=1;

		NSData *properties=nil;
		if(flags&0x20) properties=[handle readDataOfLength:ReadNumber(handle)];

		NSMutableDictionary *coder=[NSMutableDictionary dictionaryWithObjectsAndKeys:
			coderid,@"ID",
			[NSNumber numberWithInt:[instreams count]],@"FirstInStreamIndex",
			[NSNumber numberWithInt:[outstreams count]],@"FirstOutStreamIndex",
			properties,@"Properties",
		nil];

		for(int j=0;j<numinstreams;j++) [instreams addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:
			coder,@"Coder",
			[NSNumber numberWithInt:j],@"SubIndex",
		nil]];

		for(int j=0;j<numoutstreams;j++) [outstreams addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:
			coder,@"Coder",
			[NSNumber numberWithInt:j],@"SubIndex",
		nil]];

		while(flags&0x80)
		{
			flags=[handle readUInt8];
			[handle skipBytes:flags&0x0f];
			if(flags&0x10) { ReadNumber(handle); ReadNumber(handle); }
			if(flags&0x20) [handle skipBytes:ReadNumber(handle)];
		}
	}

	[dictionary setObject:instreams forKey:@"InStreams"];
	[dictionary setObject:outstreams forKey:@"OutStreams"];

	int totalinstreams=[instreams count];
	int totaloutstreams=[outstreams count];

	// Load binding pairs
	int numbindpairs=totaloutstreams-1;
	for(int i=0;i<numbindpairs;i++)
	{
		uint64_t inindex=ReadNumber(handle);
		uint64_t outindex=ReadNumber(handle);
		SetNumberEntryInArray(instreams,inindex,outindex,@"SourceIndex");
		SetNumberEntryInArray(outstreams,outindex,inindex,@"DestinationIndex");
	}

	// Load packed stream indexes, if any
	int numpackedstreams=totalinstreams-numbindpairs;
	if(numpackedstreams==1)
	{
		for(int i=0;i<totalinstreams;i++)
		if(![[instreams objectAtIndex:i] objectForKey:@"SourceIndex"])
		{
			SetObjectEntryInArray(instreams,i,[packedstreams objectAtIndex:*packedstreamindex],@"PackedStream");
			break;
		}
	}
	else
	{
		for(int i=0;i<numpackedstreams;i++)
		SetObjectEntryInArray(instreams,ReadNumber(handle),[packedstreams objectAtIndex:*packedstreamindex+i],@"PackedStream");
	}
	*packedstreamindex+=numpackedstreams;

	// Find output stream
	for(int i=0;i<totaloutstreams;i++)
	if(![[outstreams objectAtIndex:i] objectForKey:@"DestinationIndex"])
	{
		[dictionary setObject:[NSNumber numberWithInt:i] forKey:@"FinalOutStreamIndex"];
		break;
	}
}

-(void)parseSubStreamsInfoForHandle:(CSHandle *)handle folders:(NSArray *)folders
{
	int numfolders=[folders count];

	for(;;)
	{
		int type=ReadNumber(handle);
		switch(type)
		{
			case 0: return;

			case 13: // NumUnpackStreams
				for(int i=0;i<numfolders;i++)
				{
					int numsubstreams=ReadNumber(handle);
					if(numsubstreams!=1) // Re-use default substream when there is only one
					{
						NSArray *substreams=ArrayWithLength(numsubstreams);
						for(int j=0;j<numsubstreams;j++)
						{
							SetNumberEntryInArray(substreams,j,i,@"FolderIndex");
							SetNumberEntryInArray(substreams,j,j,@"SubIndex");
						}
						SetObjectEntryInArray(folders,i,substreams,@"SubStreams");
					}
				}
			break;

			case 9: // Size
				for(int i=0;i<numfolders;i++)
				{
					NSDictionary *folder=[folders objectAtIndex:i];
					NSMutableArray *substreams=[folder objectForKey:@"SubStreams"];
					int numsubstreams=[substreams count];
					uint64_t sum=0;
					for(int j=0;j<numsubstreams-1;j++)
					{
						uint64_t size=ReadNumber(handle);
						SetNumberEntryInArray(substreams,j,size,@"Size");
						SetNumberEntryInArray(substreams,j,sum,@"StartOffset");
						sum+=size;
					}

					int outindex=[[folder objectForKey:@"FinalOutStreamIndex"] intValue];
					NSDictionary *outstream=[[folder objectForKey:@"OutStreams"] objectAtIndex:outindex];
					uint64_t totalsize=[[outstream objectForKey:@"Size"] unsignedLongLongValue];

					SetNumberEntryInArray(substreams,numsubstreams-1,totalsize-sum,@"Size");
					SetNumberEntryInArray(substreams,numsubstreams-1,sum,@"StartOffset");
				}
			break;

			case 10: // CRC
			{
				NSMutableArray *crcstreams=[NSMutableArray array];
				for(int i=0;i<numfolders;i++)
				{
					NSMutableArray *substreams=[[folders objectAtIndex:i] objectForKey:@"SubStreams"];
					int numsubstreams=[substreams count];
					for(int j=0;j<numsubstreams;j++)
					{
						NSMutableDictionary *stream=[substreams objectAtIndex:j];
						if(![stream objectForKey:@"CRC"]) [crcstreams addObject:stream];
					}
				}

				[self parseCRCsForHandle:handle array:crcstreams];
			}
			break;

			default: SkipEntry(handle); break;
		}
	}
}

-(void)setupDefaultSubStreamsForFolders:(NSArray *)folders
{
	int numfolders=[folders count];
	for(int i=0;i<numfolders;i++)
	{
		NSMutableDictionary *folder=[folders objectAtIndex:i];
		int outindex=[[folder objectForKey:@"FinalOutStreamIndex"] intValue];
		NSDictionary *outstream=[[folder objectForKey:@"OutStreams"] objectAtIndex:outindex];
		NSMutableArray *substreams=ArrayWithLength(1);

		SetNumberEntryInArray(substreams,0,i,@"FolderIndex");
		SetNumberEntryInArray(substreams,0,0,@"SubIndex");
		SetNumberEntryInArray(substreams,0,0,@"StartOffset");
		SetObjectEntryInArray(substreams,0,[outstream objectForKey:@"Size"],@"Size");
		SetObjectEntryInArray(substreams,0,[folder objectForKey:@"CRC"],@"CRC");

		SetObjectEntryInArray(folders,i,substreams,@"SubStreams");
	}
}

-(NSArray *)collectAllSubStreamsFromFolders:(NSArray *)folders
{
	int numfolders=[folders count];
	NSMutableArray *allsubstreams=[NSMutableArray array];

	for(int i=0;i<numfolders;i++)
	[allsubstreams addObjectsFromArray:[[folders objectAtIndex:i] objectForKey:@"SubStreams"]];

	return allsubstreams;
}



-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum
{
	NSNumber *index=[dict objectForKey:@"7zSubStreamIndex"];
	if(!index) return nil;
	return [self handleForStreams:mainstreams substreamIndex:[index intValue] wantChecksum:checksum];
}

-(CSHandle *)handleForStreams:(NSDictionary *)streams substreamIndex:(int)substreamindex wantChecksum:(BOOL)checksum
{
	NSDictionary *substream=[[streams objectForKey:@"SubStreams"] objectAtIndex:substreamindex];
	int folderindex=[[substream objectForKey:@"FolderIndex"] intValue];
	NSDictionary *folder=[[streams objectForKey:@"Folders"] objectAtIndex:folderindex];
	int finalindex=[[folder objectForKey:@"FinalOutStreamIndex"] intValue];

	if(folder!=currfolder)
	{
		[currfolder release];
		currfolder=[folder retain];
		[currfolderhandle release];
		currfolderhandle=[[self outHandleForFolder:folder index:finalindex] retain];
	}

	uint64_t start=[[substream objectForKey:@"StartOffset"] unsignedLongLongValue];
	uint64_t size=[[substream objectForKey:@"Size"] unsignedLongLongValue];
	CSHandle *handle=[currfolderhandle nonCopiedSubHandleFrom:start length:size];

	if(checksum)
	{
		NSNumber *crc=[substream objectForKey:@"CRC"];
		if(crc) return [XADCRCHandle IEEECRC32HandleWithHandle:handle
		length:size correctCRC:[crc unsignedLongValue] conditioned:YES];
	}

	return handle;
}

-(CSHandle *)outHandleForFolder:(NSDictionary *)folder index:(int)index
{
	NSDictionary *outstream=[[folder objectForKey:@"OutStreams"] objectAtIndex:index];
	uint64_t size=[[outstream objectForKey:@"Size"] unsignedLongLongValue];
	NSDictionary *coder=[outstream objectForKey:@"Coder"];
	NSData *coderid=[coder objectForKey:@"ID"];
	const uint8_t *idbytes=[coderid bytes];
	int idlength=[coderid length];

	if(idlength==1)
	{
		if(idbytes[0]==0x00) return [self inHandleForFolder:folder coder:coder index:0];
	}
	else if(idlength==3)
	{
		if(idbytes[0]==0x03&&idbytes[1]==0x01&&idbytes[2]==0x01)
		return [[[XADLZMAHandle alloc] initWithHandle:[self inHandleForFolder:folder coder:coder index:0]
		length:size propertyData:[coder objectForKey:@"Properties"]] autorelease];
	}
	return nil;
}

-(CSHandle *)inHandleForFolder:(NSDictionary *)folder coder:(NSDictionary *)coder index:(int)index
{
	return [self inHandleForFolder:folder index:[[coder objectForKey:@"FirstInStreamIndex"] intValue]+index];
}

-(CSHandle *)inHandleForFolder:(NSDictionary *)folder index:(int)index
{
	NSDictionary *instream=[[folder objectForKey:@"InStreams"] objectAtIndex:index];

	NSDictionary *packedstream=[instream objectForKey:@"PackedStream"];
	if(packedstream)
	{
		uint64_t start=[[packedstream objectForKey:@"Offset"] unsignedLongLongValue];
		uint64_t length=[[packedstream objectForKey:@"Size"] unsignedLongLongValue];
		return [[self handle] nonCopiedSubHandleFrom:start length:length];
	}

	NSNumber *sourceindex=[instream objectForKey:@"SourceIndex"];
	if(sourceindex)
	{
		return [self outHandleForFolder:folder index:[sourceindex intValue]];
	}

	return nil;
}




-(NSString *)formatName { return @"7-Zip"; }

@end
