#import "XAD7ZipParser.h"
#import "XADLZMAHandle.h"
#import "XADDeflateHandle.h"
#import "CSZlibHandle.h"
#import "CSBzip2Handle.h"
#import "Checksums.h"

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

-(void)parse
{
	CSHandle *handle=[self handle];

	[handle skipBytes:12];

	off_t nextheaderoffs=[handle readUInt64LE];
	off_t nextheadersize=[handle readUInt64LE];

	[handle seekToFileOffset:nextheaderoffs+32];

	CSHandle *fh=handle;

	for(;;)
	{
		uint64_t type=ReadNumber(fh);
		if(type==1) break; // Header
		else if(type==23)
		{
			NSDictionary *streams=[self parseStreamsInfoForHandle:fh];
			NSArray *folders=[streams objectForKey:@"Folders"];
			if([folders count]!=1) [XADException raiseIllegalDataException];
			fh=[self handleForFolder:[folders objectAtIndex:0] substreamIndex:0];
			NSLog(@"%@",streams);
		}
		else [XADException raiseIllegalDataException];
	}

/*	for(;;)
	{
		uint64_t type=ReadNumber(fh);
	}*/


//	while(dict=)
//	[self addEntryWithDictionary:dict];
}

-(NSDictionary *)parseStreamsInfoForHandle:(CSHandle *)handle
{
	NSMutableDictionary *dict=[NSMutableDictionary dictionary];
	NSArray *folders=nil,*packedstreams=nil;
	for(;;)
	{
		uint64_t type=ReadNumber(handle);
		switch(type)
		{
			case 0: // End
				return dict;

			case 6: // PackInfo
				[dict setObject:packedstreams=[self parsePackedStreamsForHandle:handle] forKey:@"PackedStreams"];
			break;

			case 7: // CodersInfo
				[dict setObject:folders=[self parseFoldersForHandle:handle packedStreams:packedstreams] forKey:@"Folders"];
			break;

			case 8: // SubStreamsInfo
				[dict setObject:[self parseSubStreamsInfoForHandle:handle folders:folders] forKey:@"SubStreams"];
			break;

			default: [XADException raiseIllegalDataException];
		}
	}
	return nil; // can't happen
}

-(NSArray *)parsePackedStreamsForHandle:(CSHandle *)handle
{
	uint64_t dataoffset=ReadNumber(handle)+32;
	uint64_t numpackedstreams=ReadNumber(handle);
	NSMutableArray *packedstreams=ArrayWithLength(numpackedstreams);

	for(;;)
	{
		uint64_t type=ReadNumber(handle);
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

	uint64_t numfolders=ReadNumber(handle);
	NSMutableArray *folders=ArrayWithLength(numfolders);

	int external=[handle readUInt8];
	if(external!=0) [XADException raiseNotSupportedException]; // TODO: figure out how the hell to handle this

	for(int i=0;i<numfolders;i++)
	[self parseFolderForHandle:handle dictionary:[folders objectAtIndex:i] packedStreams:packedstreams];

	for(;;)
	{
		uint64_t type=ReadNumber(handle);
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
				[self parseCRCsForHandle:handle array:folders]; //....
			break;

			default: SkipEntry(handle); break;
		}
	}

	return nil; // can't happen
}

-(void)parseFolderForHandle:(CSHandle *)handle dictionary:(NSMutableDictionary *)dictionary packedStreams:(NSArray *)packedstreams
{
	uint64_t numcoders=ReadNumber(handle);
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
			SetObjectEntryInArray(instreams,i,[packedstreams objectAtIndex:0],@"PackedStream");
			break;
		}
	}
	else
	{
		for(int i=0;i<numpackedstreams;i++)
		SetObjectEntryInArray(instreams,ReadNumber(handle),[packedstreams objectAtIndex:i],@"PackedStream");
	}

	// Find output stream
	for(int i=0;i<totaloutstreams;i++)
	if(![[outstreams objectAtIndex:i] objectForKey:@"DestinationIndex"])
	{
		[dictionary setObject:[NSNumber numberWithInt:i] forKey:@"FinalOutStreamIndex"];
		break;
	}
}

-(NSArray *)parseSubStreamsInfoForHandle:(CSHandle *)handle folders:(NSArray *)folders
{
	int numfolders=[folders count];
	NSMutableArray *allsubstreams=[NSMutableArray array];

	for(;;)
	{
		uint64_t type=ReadNumber(handle);
		switch(type)
		{
			case 0: return allsubstreams;

			case 13: // NumUnpackStream
				for(int i=0;i<numfolders;i++)
				{
					int numsubstreams=ReadNumber(handle);
					NSArray *substreams=ArrayWithLength(numsubstreams);

					for(int j=0;j<numsubstreams;j++)
					{
						SetNumberEntryInArray(substreams,j,i,@"FolderIndex");
						SetNumberEntryInArray(substreams,j,j,@"SubIndex");
					}

					if(numsubstreams==1)
					{
						NSMutableDictionary *folder=[folders objectAtIndex:i];
						int outindex=[[folder objectForKey:@"FinalOutStreamIndex"] intValue];
						NSDictionary *outstream=[[folder objectForKey:@"OutStreams"] objectAtIndex:outindex];
						SetObjectEntryInArray(substreams,0,[outstream objectForKey:@"Size"],@"Size");
						SetNumberEntryInArray(substreams,0,0,@"StartOffset");
						SetObjectEntryInArray(substreams,0,[[folders objectAtIndex:i] objectForKey:@"CRC"],@"CRC");
					}

					SetObjectEntryInArray(folders,i,substreams,@"SubStreams");
					[allsubstreams addObjectsFromArray:substreams];
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
				int totalsubstreams=[allsubstreams count];

				for(int i=0;i<totalsubstreams;i++)
				{
					NSMutableDictionary *stream=[allsubstreams objectAtIndex:i];
					if(![stream objectForKey:@"CRC"]) [crcstreams addObject:stream];
				}

				[self parseCRCsForHandle:handle array:crcstreams];
			}
			break;

			default: SkipEntry(handle); break;
		}
	}
	return nil; // can't happen
}



-(NSIndexSet *)parseBoolVector:(CSHandle *)handle numberOfElements:(int)num
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

-(void)parseCRCsForHandle:(CSHandle *)handle array:(NSMutableArray *)array
{
	NSIndexSet *indexes=[self parseBoolVector:handle numberOfElements:[array count]];
	for(int i=[indexes firstIndex];i!=NSNotFound;i=[indexes indexGreaterThanIndex:i])
	SetNumberEntryInArray(array,i,[handle readUInt32LE],@"CRC");
}



-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum
{
	return nil;
}

-(CSHandle *)handleForFolder:(NSDictionary *)folder substreamIndex:(int)substream
{
	int final=[[folder objectForKey:@"FinalOutStreamIndex"] intValue];

	CSHandle *handle=[self outHandleForFolder:folder index:final];

	// TODO: substream,crc

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
