#import "XADUnarchiver.h"
#import "CSFileHandle.h"
#import "NSDateXAD.h"

#import <fcntl.h>
#import <unistd.h>
#import <sys/stat.h>
#import <sys/time.h>
#import <sys/attr.h>
#import <sys/xattr.h>

@implementation XADUnarchiver (PlatformSpecific)

-(XADError)_extractResourceForkEntryWithDictionary:(NSDictionary *)dict asPlatformSpecificForkForFile:(NSString *)destpath
{
	// Make sure a plain file exists at this path before proceeding.
	const char *cpath=[destpath fileSystemRepresentation];
	struct stat st;
	if(lstat(cpath,&st)==0)
	{
		// If something exists that is not a regular file, try deleting it.
		if((st.st_mode&S_IFMT)!=S_IFREG)
		{
			if(unlink(cpath)!=0) return XADOpenFileError; // TODO: better error
		}
	}
	else
	{
		// If nothing exists, create an empty file.
		int fh=open(cpath,O_WRONLY|O_CREAT|O_TRUNC,0666);
		if(fh==-1) return XADOpenFileError;
		close(fh);
	}

	// Then, unpack to resource fork.
	NSString *forkpath=[destpath stringByAppendingPathComponent:@"..namedfork/rsrc"];
	int originalpermissions=-1;
	CSHandle *fh=nil;

	@try { fh=[CSFileHandle fileHandleForWritingAtPath:forkpath]; }
	@catch(id e) {}

	// If opening the resource fork failed, change permissions on the file and try again.
	if(!fh)
	{
		struct stat st;
		stat(cpath,&st);
		originalpermissions=st.st_mode;

		chmod(cpath,0700);

		@try { fh=[CSFileHandle fileHandleForWritingAtPath:forkpath]; }
		@catch(id e) { return XADOpenFileError; }
	}

	XADError error=[self _extractEntryWithDictionary:dict toHandle:fh];

	[fh close];

	if(originalpermissions!=-1) chmod(cpath,originalpermissions);

	return error;
}

-(XADError)_createPlatformSpecificLinkToPath:(NSString *)link from:(NSString *)path
{
	struct stat st;
	const char *destcstr=[path fileSystemRepresentation];
	if(lstat(destcstr,&st)==0) unlink(destcstr);
	if(symlink([link fileSystemRepresentation],destcstr)!=0) return XADOutputError;

	return XADNoError;
}

-(XADError)_updatePlatformSpecificFileAttributesAtPath:(NSString *)path forEntryWithDictionary:(NSDictionary *)dict
{
	const char *cpath=[path fileSystemRepresentation];

	// Read file permissions.
	struct stat st;
	if(stat(cpath,&st)!=0) return XADOpenFileError; // TODO: better error

	// If the file does not have write permissions, change this temporarily.
	if(!(st.st_mode&S_IWUSR)) chmod(cpath,0700);

	// Write extended attributes.
	NSDictionary *extattrs=[parser extendedAttributesForDictionary:dict];
	if(extattrs)
	{
		NSEnumerator *enumerator=[extattrs keyEnumerator];
		NSString *key;
		while((key=[enumerator nextObject]))
		{
			NSData *data=[extattrs objectForKey:key];

			int namelen=[key lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
			char namebytes[namelen+1];
			[key getCString:namebytes maxLength:sizeof(namebytes) encoding:NSUTF8StringEncoding];

			setxattr(cpath,namebytes,[data bytes],[data length],0,XATTR_NOFOLLOW);
		}
	}

	// Attrlist structures.
	struct attrlist list={ ATTR_BIT_MAP_COUNT };
	uint8_t attrdata[3*sizeof(struct timespec)+sizeof(uint32_t)];
	uint8_t *attrptr=attrdata;

	// Handle timestamps.
	NSDate *creation=[dict objectForKey:XADCreationDateKey];
	NSDate *modification=[dict objectForKey:XADLastModificationDateKey];
	NSDate *access=[dict objectForKey:XADLastAccessDateKey];

	if(creation)
	{
		list.commonattr|=ATTR_CMN_CRTIME;
		*((struct timespec *)attrptr)=[creation timespecStruct];
		attrptr+=sizeof(struct timeval);
	}
	if(modification)
	{
		list.commonattr|=ATTR_CMN_MODTIME;
		*((struct timespec *)attrptr)=[modification timespecStruct];
		attrptr+=sizeof(struct timeval);
	}
	if(access)
	{
		list.commonattr|=ATTR_CMN_ACCTIME;
		*((struct timespec *)attrptr)=[access timespecStruct];
		attrptr+=sizeof(struct timeval);
	}

	// Figure out permissions, or reuse the earlier value.
	mode_t mode=st.st_mode;
	NSNumber *permissions=[dict objectForKey:XADPosixPermissionsKey];
	if(permissions)
	{
		mode=[permissions unsignedShortValue];
		if(!preservepermissions)
		{
			mode_t mask=umask(022);
			umask(mask); // This is stupid. Is there no sane way to just READ the umask?
			mode&=~(mask|S_ISUID|S_ISGID);
		}
	}

	// Add permissions to attribute list.
	list.commonattr|=ATTR_CMN_ACCESSMASK;
	*((uint32_t *)attrptr)=mode;
	attrptr+=sizeof(uint32_t);

	// Finally, set all attributes.
	setattrlist(cpath,&list,attrdata,attrptr-attrdata,FSOPT_NOFOLLOW);

	return XADNoError;
}

@end

double _XADUnarchiverGetTime()
{
	struct timeval tv;
	gettimeofday(&tv,NULL);
	return (double)tv.tv_sec+(double)tv.tv_usec/1000000.0;
}
