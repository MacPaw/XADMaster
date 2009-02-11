#import "XADDittoParser.h"

NSString *XADIsMacBinaryKey=@"XADIsMacBinary";

@implementation XADDittoParser
-(void)addEntryWithDictionary:(NSDictionary *)dictionary
{
/*
	if([self _isDittoResourceFork:entry])
	{
		int n=[self _entryIndexOfDataForkForDittoResourceFork:entry];

		NSMutableDictionary *dict=[entries objectAtIndex:n];
		[dict setObject:entry forKey:XADDittoPropertiesKey];

		// TODO: deal with unpacking
		// ...
	}
	else [self addEntryWithDictionary:entry];
*/
}
/*
-(BOOL)_isDittoResourceFork:(NSDictionary *)properties
{
	NSString *name=[[properties objectForKey:XADFileNameKey] stringWithEncoding:NSUTF8StringEncoding];
	if(!name) return NO;
	return [name isEqual:@"__MACOSX"]||[name hasPrefix:@"__MACOSX/"]||[[name lastPathComponent] hasPrefix:@"._"];
}

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

-(void)_parseDittoResourceFork:(NSDictionary *)properties intoAttributes:(NSMutableDictionary *)attrs
{
	NSData *apple=[self _contentsOfFileInfo:info];
	if(apple)
	{
		int len=[apple length];
		const void *bytes=[apple bytes];

		if(len>=26&&EndGetM32(bytes)==0x00051607&&EndGetM32(bytes+4)==0x00020000)
		{
			int num=EndGetM16(bytes+24);
			if(len>=26+num*12)
			{
				for(int i=0;i<num;i++)
				{
					unsigned long entryid=EndGetM32(bytes+26+i*12+0);
					unsigned long entryoffs=EndGetM32(bytes+26+i*12+4);
					unsigned long entrylen=EndGetM32(bytes+26+i*12+8);

					if(entryoffs+entrylen<=len)
					switch(entryid)
					{
						case 2: // resource fork
							[attrs setObject:[apple subdataWithRange:NSMakeRange(entryoffs,entrylen)] forKey:XADResourceForkData];
						break;
						case 9: // finder
							[attrs setObject:[NSNumber numberWithUnsignedLong:EndGetM32(bytes+entryoffs)] forKey:NSFileHFSTypeCode];
							[attrs setObject:[NSNumber numberWithUnsignedLong:EndGetM32(bytes+entryoffs+4)] forKey:NSFileHFSCreatorCode];
							[attrs setObject:[NSNumber numberWithUnsignedShort:EndGetM16(bytes+entryoffs+8)] forKey:XADFinderFlags];
						break;
					}
				}
			}
		}
	}
}
*/

@end
