#import "XADArchiveParserDescriptions.h"
#import "XADRegex.h"

@implementation XADArchiveParser (Descriptions)

-(NSString *)descriptionOfValueInDictionary:(NSDictionary *)dict key:(NSString *)key
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
	static NSDictionary *descriptions=nil;
	if(!descriptions) descriptions=[[NSDictionary alloc] initWithObjectsAndKeys:
		@"Comment",XADCommentKey,
		@"Name",XADFileNameKey,
		@"Size",XADFileSizeKey,
		@"Compressed size",XADCompressedSizeKey,
		@"Compression type",XADCompressionNameKey,

		@"Is directory",XADIsDirectoryKey,
		@"Is Mac OS resource fork",XADIsResourceForkKey,
		@"Is an archive",XADIsArchiveKey,
		@"Is hidden",XADIsHiddenKey,
		@"Is a link",XADIsLinkKey,
		@"Is a hard link",XADIsHardLinkKey,
		@"Link destination",XADLinkDestinationKey,
		@"Is a Unix character device",XADIsCharacterDeviceKey,
		@"Is a Unix block device",XADIsBlockDeviceKey,
		@"Unix major device number",XADDeviceMajorKey,
		@"Unix minor device number",XADDeviceMinorKey,
		@"Is a Unix FIFO",XADIsFIFOKey,
		@"Is encrypted",XADIsEncryptedKey,
		@"Is corrupted",XADIsCorruptedKey,

		@"Last modification time",XADLastModificationDateKey,
		@"Last access time",XADLastAccessDateKey,
		@"Last attribute change time",XADLastAttributeChangeDateKey,
		@"Creation time",XADCreationDateKey,

		@"Extended attributes",XADExtendedAttributesKey,
		@"Mac OS type code",XADFileTypeKey,
		@"Mac OS creator code",XADFileCreatorKey,
		@"Mac OS Finder flags",XADFinderFlagsKey,
		@"Mac OS Finder info",XADFinderInfoKey,
		@"Unix permissions",XADPosixPermissionsKey,
		@"Unix user number",XADPosixUserKey,
		@"Unix group number",XADPosixGroupKey,
		@"Unix user name",XADPosixUserNameKey,
		@"Unix group name",XADPosixGroupNameKey,
		@"DOS file attributes",XADDOSFileAttributesKey,
		@"Windows file attributes",XADWindowsFileAttributesKey,
		@"Amiga protection bits",XADAmigaProtectionBitsKey,

		@"Index in file",XADIndexKey,
		@"Start of data",XADDataOffsetKey,
		@"Length of data",XADDataLengthKey,
		@"Start of data (minus skips)",XADSkipOffsetKey,
		@"Length of data (minus skips)",XADSkipLengthKey,

		@"Is a solid archive file",XADIsSolidKey,
		@"Index of first solid file",XADFirstSolidIndexKey,
		@"Pointer to first solid file",XADFirstSolidEntryKey,
		@"Index of next solid file",XADNextSolidIndexKey,
		@"Pointer to next solid file",XADNextSolidEntryKey,
		@"Internal solid identifier",XADSolidObjectKey,
		@"Start of data in solid stream",XADSolidOffsetKey,
		@"Length of data in solid stream",XADSolidLengthKey,

		@"Archive name",XADArchiveNameKey,
		@"Archive volumes",XADVolumesKey,
		@"Disk label",XADDiskLabelKey,
		nil];

	NSString *description=[descriptions objectForKey:key];
	if(description) return description;

	return key;
}

static NSInteger OrderKeys(id first,id second,void *context);

-(NSArray *)descriptiveOrderingOfKeysInDictionary:(NSDictionary *)dict
{
	static NSDictionary *ordering=nil;
	if(!ordering) ordering=[[NSDictionary alloc] initWithObjectsAndKeys:
		[NSNumber numberWithInt:100],XADFileNameKey,
		[NSNumber numberWithInt:101],XADCommentKey,
		[NSNumber numberWithInt:102],XADFileSizeKey,
		[NSNumber numberWithInt:103],XADCompressedSizeKey,
		[NSNumber numberWithInt:104],XADCompressionNameKey,

		[NSNumber numberWithInt:200],XADIsDirectoryKey,
		[NSNumber numberWithInt:201],XADIsResourceForkKey,
		[NSNumber numberWithInt:202],XADIsArchiveKey,
		[NSNumber numberWithInt:203],XADIsHiddenKey,
		[NSNumber numberWithInt:204],XADIsLinkKey,
		[NSNumber numberWithInt:205],XADIsHardLinkKey,
		[NSNumber numberWithInt:206],XADLinkDestinationKey,
		[NSNumber numberWithInt:207],XADIsCharacterDeviceKey,
		[NSNumber numberWithInt:208],XADIsBlockDeviceKey,
		[NSNumber numberWithInt:209],XADDeviceMajorKey,
		[NSNumber numberWithInt:210],XADDeviceMinorKey,
		[NSNumber numberWithInt:211],XADIsFIFOKey,
		[NSNumber numberWithInt:212],XADIsEncryptedKey,
		[NSNumber numberWithInt:213],XADIsCorruptedKey,

		[NSNumber numberWithInt:300],XADLastModificationDateKey,
		[NSNumber numberWithInt:301],XADLastAccessDateKey,
		[NSNumber numberWithInt:302],XADLastAttributeChangeDateKey,
		[NSNumber numberWithInt:303],XADCreationDateKey,

		[NSNumber numberWithInt:400],XADExtendedAttributesKey,
		[NSNumber numberWithInt:401],XADFileTypeKey,
		[NSNumber numberWithInt:402],XADFileCreatorKey,
		[NSNumber numberWithInt:403],XADFinderFlagsKey,
		[NSNumber numberWithInt:404],XADFinderInfoKey,
		[NSNumber numberWithInt:404],XADPosixPermissionsKey,
		[NSNumber numberWithInt:405],XADPosixUserKey,
		[NSNumber numberWithInt:406],XADPosixGroupKey,
		[NSNumber numberWithInt:407],XADPosixUserNameKey,
		[NSNumber numberWithInt:408],XADPosixGroupNameKey,
		[NSNumber numberWithInt:409],XADDOSFileAttributesKey,
		[NSNumber numberWithInt:410],XADWindowsFileAttributesKey,
		[NSNumber numberWithInt:411],XADAmigaProtectionBitsKey,

		[NSNumber numberWithInt:500],XADIndexKey,
		[NSNumber numberWithInt:501],XADDataOffsetKey,
		[NSNumber numberWithInt:502],XADDataLengthKey,
		[NSNumber numberWithInt:503],XADSkipOffsetKey,
		[NSNumber numberWithInt:504],XADSkipLengthKey,

		[NSNumber numberWithInt:600],XADIsSolidKey,
		[NSNumber numberWithInt:601],XADFirstSolidIndexKey,
		[NSNumber numberWithInt:602],XADFirstSolidEntryKey,
		[NSNumber numberWithInt:603],XADNextSolidIndexKey,
		[NSNumber numberWithInt:604],XADNextSolidEntryKey,
		[NSNumber numberWithInt:605],XADSolidObjectKey,
		[NSNumber numberWithInt:606],XADSolidOffsetKey,
		[NSNumber numberWithInt:607],XADSolidLengthKey,

		[NSNumber numberWithInt:700],XADArchiveNameKey,
		[NSNumber numberWithInt:701],XADVolumesKey,
		[NSNumber numberWithInt:702],XADDiskLabelKey,
		nil];

	return [[dict allKeys] sortedArrayUsingFunction:OrderKeys context:ordering];
}

static NSInteger OrderKeys(id first,id second,void *context)
{
	NSDictionary *ordering=context;
	NSNumber *firstorder=[ordering objectForKey:first];
	NSNumber *secondorder=[ordering objectForKey:second];

	if(firstorder&&secondorder) return [firstorder compare:secondorder];
	else if(firstorder) return NSOrderedAscending;
	else if(secondorder) return NSOrderedDescending;
	else return [first compare:second];
}

@end
