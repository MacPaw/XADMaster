#import "XADSplitFileParser.h"

@implementation XADSplitFileParser

+(int)requiredHeaderSize { return 0; }

+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name
{
	if(!name) return NO;

	
}

+(NSArray *)volumesForFilename:(NSString *)filename
{
	NSArray *matches;

	if(matches=[filename substringsCapturedByPattern:@"^(.*)\\.(alz|a[0-9]{2}|b[0-9]{2})$" options:REG_ICASE])
	{
		return [self scanForVolumesWithFilename:filename
		regex:[XADRegex regexWithPattern:[NSString stringWithFormat:@"^%@\\.(alz|a[0-9]{2}|b[0-9]{2})$",
			[[matches objectAtIndex:1] escapedPattern]] options:REG_ICASE]
		firstFileExtension:@"alz"];
	}

	return nil;
}

-(void)parse
{
}

-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum
{
	CSHandle *handle=[self handle];
	[handle seekToFileOffset:0];
	return handle;
}

-(NSString *)formatName { return @"Split file"; }

@end
