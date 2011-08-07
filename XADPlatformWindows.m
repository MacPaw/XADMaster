#import "XADUnarchiver.h"
#import "NSDateXAD.h"

#import <windows.h>
#import <sys/stat.h>




// TODO: Implement proper handling of Windows metadata.

@implementation XADPlatform

+(XADError)extractResourceForkEntryWithDictionary:(NSDictionary *)dict
unarchiver:(XADUnarchiver *)unarchiver toPath:(NSString *)destpath
{
	return XADNotSupportedError;
}

+(XADError)updateFileAttributesAtPath:(NSString *)path
forEntryWithDictionary:(NSDictionary *)dict parser:(XADArchiveParser *)parser
preservePermissions:(BOOL)preservepermissions
{
	const wchar_t *wpath=[path fileSystemRepresentationW];

	// If the file is read-only, change this temporarily and remember to change back.
	BOOL changedattributes=NO;
	DWORD oldattributes=GetFileAttributesW(wpath);
	if(oldattributes!=INVALID_FILE_ATTRIBUTES&&(oldattributes&FILE_ATTRIBUTE_READONLY))
	{
		SetFileAttributesW(wpath,oldattributes&~INVALID_FILE_ATTRIBUTES);
		changedattributes=YES;
	}

	NSDate *modification=[dict objectForKey:XADLastModificationDateKey];
	NSDate *creation=[dict objectForKey:XADCreationDateKey];
	NSDate *access=[dict objectForKey:XADLastAccessDateKey];

	if(modification||creation||access)
	{
		HANDLE handle=CreateFileW(wpath,GENERIC_WRITE,FILE_SHARE_WRITE,NULL,OPEN_EXISTING,FILE_FLAG_BACKUP_SEMANTICS,NULL);
		if(handle==INVALID_HANDLE_VALUE) return XADUnknownError; // TODO: better error

		FILETIME creationtime,lastaccesstime,lastwritetime;

		if(creation) creationtime=[creation FILETIME];
		if(access) lastaccesstime=[access FILETIME];
		if(modification) lastwritetime=[modification FILETIME];

		if(!SetFileTime(handle,
		creation?&creationtime:NULL,
		access?&lastaccesstime:NULL,
		modification?&lastwritetime:NULL))
		{
			CloseHandle(handle);
			return XADUnknownError; // TODO: better error
		}

		CloseHandle(handle);
	}

	NSNumber *attributes=[dict objectForKey:XADWindowsFileAttributesKey];
	if(!attributes) attributes=[dict objectForKey:XADDOSFileAttributesKey];
	if(attributes||changedattributes)
	{
		DWORD newattributes=oldattributes;
		if(attributes) newattributes=[attributes intValue];
		SetFileAttributesW(wpath,newattributes);
	}

	return XADNoError;
}

+(XADError)createLinkAtPath:(NSString *)path withDestinationPath:(NSString *)link
{
	return XADNotSupportedError;
}

+(id)readCloneableMetadataFromPath:(NSString *)path { return nil; }
+(void)writeCloneableMetadata:(id)metadata toPath:(NSString *)path {}

+(NSString *)uniqueDirectoryPathWithParentDirectory:(NSString *)parent
{
	NSDate *now=[NSDate date];
	int64_t t=[now timeIntervalSinceReferenceDate]*1000000000;

	NSString *dirname=[NSString stringWithFormat:@"XADTemp%qd",t];

	if(parent) return [parent stringByAppendingPathComponent:dirname];
	else return dirname;
}

+(double)currentTimeInSeconds
{
	return (double)timeGetTime()/1000.0;
}

@end
