#import "XADMacArchiveParser.h"

NSString *XADIsMacBinaryKey=@"XADIsMacBinary";

@implementation XADMacArchiveParser

-(id)initWithHandle:(CSHandle *)handle name:(NSString *)name;
{
	if(self=[super initWithHandle:handle name:name])
	{
		dittohandle=nil;
	}
	return self;
}

-(void)addEntryWithDictionary:(NSMutableDictionary *)dict retainPosition:(BOOL)retainpos
{
	if([self isDittoResourceFork:dict])
	{
		dittohandle=[self rawHandleForEntryWithDictionary:dict wantChecksum:YES];

		NSMutableDictionary *doubledict=[self parseAppleDoubleWithHandle:dittohandle template:dict];
		if(doubledict)
		{
			[doubledict setObject:dict forKey:@"MacOriginalDictionary"];

			[super addEntryWithDictionary:doubledict retainPosition:retainpos];
		}
		else [super addEntryWithDictionary:dict retainPosition:retainpos];
	}
	else [super addEntryWithDictionary:dict retainPosition:retainpos];
}

-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum
{
	NSDictionary *origdict=[dict objectForKey:@"MacOriginalDictionary"];
	if(origdict)
	{
		off_t offset=[[dict objectForKey:@"MacResourceOffset"] longLongValue];
		off_t length=[[dict objectForKey:@"MacResourceLength"] longLongValue];

		CSHandle *handle;
		if(dittohandle) handle=dittohandle;
		else handle=[self rawHandleForEntryWithDictionary:origdict wantChecksum:checksum];

		return [handle nonCopiedSubHandleFrom:offset length:length];
	}
	else return [self rawHandleForEntryWithDictionary:dict wantChecksum:checksum];
}

-(BOOL)isDittoResourceFork:(NSMutableDictionary *)dict
{
	NSString *name=[[dict objectForKey:XADFileNameKey] string];
	if(!name) return NO;
	return [name isEqual:@"__MACOSX"]||[name hasPrefix:@"__MACOSX/"]||[[name lastPathComponent] hasPrefix:@"._"];
}

/*
-(NSString *)_entryIndexOfDataForkForDittoResourceFork:(NSDictionary *)properties
{
	//if(![self _fileInfoIsDittoResourceFork:info]) return NSNotFound; // redundant
	NSNumber *dir=[properties objectForKey:XADIsDirectoryKey];
	if(dir&&[dir booleanValue]) return NSNotFound; // Skip directories under __MACOS/

	NSString *name=[[properties objectForKey:XADFileNameKey] stringWithEncoding:NSUTF8StringEncoding];
	if([name hasPrefix:@"__MACOSX/"]) name=[name substringFromIndex:9];
	else if([name hasPrefix:@"./"]) name=[name substringFromIndex:2];

	NSString *filepart=[name lastPathComponent];
	NSString *pathpart=[name stringByDeletingLastPathComponent];
	if([filepart hasPrefix:@"._"]) filepart=[filepart substringFromIndex:2];

	name=[pathpart stringByAppendingPathComponent:filepart];

	int numentries=[self numberOfEntries];
	for(int i=0;i<numentries;i++) if([name isEqual:[self nameOfEntry:i]]) return i;
	return NSNotFound;
}
*/

-(NSMutableDictionary *)parseAppleDoubleWithHandle:(CSHandle *)fh template:(NSDictionary *)template
{
	NSMutableDictionary *dict=[NSMutableDictionary dictionaryWithDictionary:template];

	@try
	{
		if([fh readUInt32BE]!=0x00051607) return nil;
		if([fh readUInt32BE]!=0x00020000) return nil;
		[fh skipBytes:16];
		int num=[fh readUInt16BE];

		uint32_t rsrcoffs=0,rsrclen=0;
		uint32_t finderoffs=0,finderlen=0;

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

		if(!rsrcoffs) return nil;

		[dict setObject:[NSNumber numberWithUnsignedInt:rsrcoffs] forKey:@"MacResourceOffset"];
		[dict setObject:[NSNumber numberWithUnsignedInt:rsrclen] forKey:@"MacResourceLength"];
		[dict setObject:[NSNumber numberWithUnsignedInt:rsrclen] forKey:XADFileSizeKey];
		[dict setObject:[NSNumber numberWithBool:YES] forKey:XADIsResourceForkKey];
		[dict removeObjectForKey:XADDataLengthKey];
		[dict removeObjectForKey:XADDataOffsetKey];

		if(finderoffs)
		{
			[fh seekToFileOffset:finderoffs];
			NSData *finderinfo=[fh readDataOfLength:finderlen];
			[dict setObject:finderinfo forKey:XADFinderInfoKey];
		}
	}
	@catch(id e)
	{
		return nil;
	}

	return dict;
}

-(CSHandle *)rawHandleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum
{
	return nil;
}

@end
