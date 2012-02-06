#import "XADArchiveParserDescriptions.h"
#import "XADRegex.h"

@implementation XADArchiveParser (Descriptions)

-(NSString *)descriptionOfEntryInDictionary:(NSDictionary *)dict key:(NSString *)key
{
	id object=[dict objectForKey:key];
	if(!object) return nil;

	if([key matchedByPattern:@"CRC32$"])
	{
		if(![object isKindOfClass:[NSNumber class]]) return [object description];
		return [NSString stringWithFormat:@"0x%08x",[object unsignedLongValue]];
	}
	else if([key matchedByPattern:@"CRC16$"])
	{
		if(![object isKindOfClass:[NSNumber class]]) return [object description];
		return [NSString stringWithFormat:@"0x%04x",[object unsignedShortValue]];
	}
	else if([key matchedByPattern:@"Is[A-Z0-9]"])
	{
		if(![object isKindOfClass:[NSNumber class]]) return [object description];
		if([object longLongValue]==1) return @"Yes";
		else if ([object longLongValue]==0) return @"No";
		else return [object description];
	}
	else if([key isEqual:XADFileSizeKey]||[key isEqual:XADCompressedSizeKey])
	{
		return [object description];
	}
	else if([key isEqual:XADFileTypeKey]||[key isEqual:XADFileCreatorKey])
	{
		if(![object isKindOfClass:[NSNumber class]]) return [object description];
		int64_t code=[object longLongValue];
		char str[5]={0};
		for(int i=0;i<4;i++)
		{
			uint8_t c=(code>>(24-i*8))&0xff;
			if(c>=32&&c<=127) str[i]=c;
			else str[i]='?';
		}
		return [NSString stringWithFormat:@"%s (0x%08llx)",str,code];
	}
	else if([key isEqual:XADPosixPermissionsKey])
	{
		if(![object isKindOfClass:[NSNumber class]]) return [object description];
		int64_t perms=[object longLongValue];
		char str[10]="rwxrwxrwx";
		for(int i=0;i<9;i++) if(!(perms&(0400>>i))) str[i]='-';
		return [NSString stringWithFormat:@"%s (%llo)",str,perms];
	}
	else if([object isKindOfClass:[NSDate class]])
	{
		return [NSDateFormatter localizedStringFromDate:object
		dateStyle:NSDateFormatterFullStyle timeStyle:NSDateFormatterMediumStyle];
	}
	else
	{
		return [object description];
	}
}

-(NSString *)descriptionOfKey:(NSString *)key
{
/*extern NSString *XADIndexKey;
extern NSString *XADFileNameKey;
extern NSString *XADFileSizeKey;
extern NSString *XADCompressedSizeKey;
extern NSString *XADLastModificationDateKey;
extern NSString *XADLastAccessDateKey;
extern NSString *XADLastAttributeChangeDateKey;
extern NSString *XADCreationDateKey;
extern NSString *XADExtendedAttributesKey;
extern NSString *XADFileTypeKey;
extern NSString *XADFileCreatorKey;
extern NSString *XADFinderFlagsKey;
extern NSString *XADFinderInfoKey;
extern NSString *XADPosixPermissionsKey;
extern NSString *XADPosixUserKey;
extern NSString *XADPosixGroupKey;
extern NSString *XADPosixUserNameKey;
extern NSString *XADPosixGroupNameKey;
extern NSString *XADDOSFileAttributesKey;
extern NSString *XADWindowsFileAttributesKey;
extern NSString *XADAmigaProtectionBitsKey;

extern NSString *XADIsEncryptedKey;
extern NSString *XADIsCorruptedKey;
extern NSString *XADIsDirectoryKey;
extern NSString *XADIsResourceForkKey;
extern NSString *XADIsArchiveKey;
extern NSString *XADIsHiddenKey;
extern NSString *XADIsLinkKey;
extern NSString *XADIsHardLinkKey;
extern NSString *XADLinkDestinationKey;
extern NSString *XADIsCharacterDeviceKey;
extern NSString *XADIsBlockDeviceKey;
extern NSString *XADDeviceMajorKey;
extern NSString *XADDeviceMinorKey;
extern NSString *XADIsFIFOKey;

extern NSString *XADCommentKey;
extern NSString *XADDataOffsetKey;
extern NSString *XADDataLengthKey;
extern NSString *XADSkipOffsetKey;
extern NSString *XADSkipLengthKey;
extern NSString *XADCompressionNameKey;

extern NSString *XADIsSolidKey;
extern NSString *XADFirstSolidIndexKey;
extern NSString *XADFirstSolidEntryKey;
extern NSString *XADNextSolidIndexKey;
extern NSString *XADNextSolidEntryKey;
extern NSString *XADSolidObjectKey;
extern NSString *XADSolidOffsetKey;
extern NSString *XADSolidLengthKey;
*/
	return nil;
}

@end
