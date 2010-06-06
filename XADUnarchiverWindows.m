#import "XADUnarchiver.h"
#import "NSDateXAD.h"

#import <windows.h>
#import <sys/stat.h>

// TODO: Implement proper handling of Windows metadata.

@implementation XADUnarchiver (PlatformSpecific)

-(XADError)_extractResourceForkEntryWithDictionary:(NSDictionary *)dict asPlatformSpecificForkForFile:(NSString *)destpath
{
	return XADNotSupportedError;
}

-(XADError)_createPlatformSpecificLinkToPath:(NSString *)link from:(NSString *)path
{
	return XADNotSupportedError;
}

-(XADError)_updatePlatformSpecificFileAttributesAtPath:(NSString *)path forEntryWithDictionary:(NSDictionary *)dict
{
	const wchar_t *wpath=[path fileSystemRepresentationW];

//	struct stat st;
//	if(stat(cpath,&st)!=0) return XADOpenFileError; // TODO: better error

/*	// If the file does not have write permissions, change this temporarily
	// and remember to change back.
	BOOL changedpermissions=NO;
	if(!(st.st_mode&S_IWUSR))
	{
		chmod(cpath,0700);
		changedpermissions=YES;
	}*/

	// Handle timestamps.
/*	NSDate *modification=[dict objectForKey:XADLastModificationDateKey];
	NSDate *access=[dict objectForKey:XADLastAccessDateKey];

	if(modification||access)
	{
		struct timeval times[2]={
			{st.st_atime,0},
			{st.st_mtime,0},
		};

		if(access) times[0]=[access timevalStruct];
		if(modification) times[1]=[modification timevalStruct];

		if(utimes(cpath,times)!=0) return XADUnknownError; // TODO: better error
	}*/

	NSNumber *attributes=[dict objectForKey:XADWindowsFileAttributesKey];
	if(!attributes) attributes=[dict objectForKey:XADDOSFileAttributesKey];
	if(attributes)
	{
		SetFileAttributesW(wpath,[attributes intValue]);
	}

	// Handle permissions (or change back to original permissions if they were changed).
/*	NSNumber *permissions=[dict objectForKey:XADPosixPermissionsKey];
	if(permissions||changedpermissions)
	{
		mode_t mode=st.st_mode;

		if(permissions)
		{
			mode=[permissions unsignedShortValue];
			if(!preservepermissions)
			{
				mode_t mask=umask(022);
				umask(mask); // This is stupid. Is there no sane way to just READ the umask?
				mode&=~mask;
			}
		}

		if(chmod(cpath,mode&~S_IFMT)!=0) return XADUnknownError; // TODO: better error
	}*/

	return XADNoError;
}

@end

double _XADUnarchiverGetTime()
{
	return (double)timeGetTime()/1000.0;
}
