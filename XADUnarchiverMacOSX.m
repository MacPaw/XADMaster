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

struct ResourceOutputArguments
{
	int fd,offset;
};

-(XADError)_extractResourceForkEntryWithDictionary:(NSDictionary *)dict asPlatformSpecificForkForFile:(NSString *)destpath
{
	const char *cpath=[destpath fileSystemRepresentation];
	int originalpermissions=-1;

	// Open the file for writing, creating it if it doesn't exist.
	// TODO: Does it need to be opened for writing or is read enough?
	int fd=open(cpath,O_WRONLY|O_CREAT|O_NOFOLLOW,0666);
	if(fd==-1) 
	{
		// If opening the file failed, try changing permissions.
		struct stat st;
		stat(cpath,&st);
		originalpermissions=st.st_mode;

		chmod(cpath,0700);

		fd=open(cpath,O_WRONLY|O_CREAT|O_NOFOLLOW,0666);
		if(fd==-1) return XADOpenFileError; // TODO: Better error.
	}

	struct ResourceOutputArguments args={ .fd=fd, .offset=0 };

	XADError error=[self runExtractorWithDictionary:dict
	outputTarget:self selector:@selector(_outputToResourceFork:bytes:length:)
	argument:[NSValue valueWithPointer:&args]];

	close(fd);

	if(originalpermissions!=-1) chmod(cpath,originalpermissions);

	return error;
}

-(XADError)_outputToResourceFork:(NSValue *)pointerval bytes:(uint8_t *)bytes length:(int)length
{
	struct ResourceOutputArguments *args=[pointerval pointerValue];
	if(fsetxattr(args->fd,XATTR_RESOURCEFORK_NAME,bytes,length,
	args->offset,0)) return XADOutputError;

	args->offset+=length;

	return XADNoError;
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
