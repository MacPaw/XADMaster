#import "XADUnarchiver.h"
#import "Progress.h"
#import "NSDateXAD.h"

#import <sys/stat.h>
#import <sys/time.h>

static double XADGetTime();

@implementation XADUnarchiver

+(XADUnarchiver *)unarchiverForArchiveParser:(XADArchiveParser *)archiveparser
{
	return [[[self alloc] initWithArchiveParser:archiveparser] autorelease];
}

+(XADUnarchiver *)unarchiverForPath:(NSString *)path
{
	XADArchiveParser *archiveparser=[XADArchiveParser archiveParserForPath:path];
	if(!archiveparser) return nil;
	return [[[self alloc] initWithArchiveParser:archiveparser] autorelease];
}

-(id)initWithArchiveParser:(XADArchiveParser *)archiveparser
{
	if(self=[super init])
	{
		parser=[archiveparser retain];
		destination=nil;
		forkstyle=XADDefaultForkStyle;
		preservepermissions=NO;
		updateinterval=0.1;
		delegate=nil;

		deferreddirectories=[NSMutableArray new];

		[parser setDelegate:self];
	}
	return self;
}

-(void)dealloc
{
	[parser release];
	[destination release];
	[deferreddirectories release];
	[super dealloc];
}

-(id)delegate { return delegate; }
-(void)setDelegate:(id)newdelegate { delegate=newdelegate; }

//-(NSString *)password;
//-(void)setPassword:(NSString *)password;

//-(NSStringEncoding)encoding;
//-(void)setEncoding:(NSStringEncoding)encoding;

-(NSString *)destination { return destination; }

-(void)setDestination:(NSString *)destpath
{
	[destination autorelease];
	destination=[destpath retain];
}

-(int)macResourceForkStyle { return forkstyle; }

-(void)setMacResourceForkStyle:(int)style { forkstyle=style; }

-(BOOL)preservesPermissions { return preservepermissions; }

-(void)setPreserevesPermissions:(BOOL)preserveflag { preservepermissions=preserveflag; }

-(double)updateInterval { return updateinterval; }

-(void)setUpdateInterval:(double)interval { updateinterval=interval; }



-(XADError)parseAndUnarchive
{
	@try
	{
		[parser parse];
	}
	@catch(id e)
	{
		return [XADException parseException:e];
	}

	return [self finishExtractions];
}

-(XADError)extractEntryWithDictionary:(NSDictionary *)dict
{
	return [self extractEntryWithDictionary:dict forceDirectories:NO];
}

-(XADError)extractEntryWithDictionary:(NSDictionary *)dict forceDirectories:(BOOL)force
{
	NSAutoreleasePool *pool=[NSAutoreleasePool new];

	NSString *path=nil;

	// Ask the delegate for its opinion on the output path.
	if(delegate) path=[delegate unarchiver:self pathForExtractingEntryWithDictionary:dict];

	// If we were not given a path, pick one ourselves.
	if(!path)
	{
		XADPath *name=[[dict objectForKey:XADFileNameKey] safePath];
		if(destination) path=[destination stringByAppendingPathComponent:[name string]];
		else path=[name string];
	}

	// If we are unpacking a resource fork, we may need to modify the path
	NSNumber *resnum=[dict objectForKey:XADIsResourceForkKey];
	if(resnum&&[resnum boolValue])
	{
		switch(forkstyle)
		{
			case XADHiddenAppleDoubleForkStyle:
				// TODO: is this path generation correct?
				path=[[path stringByDeletingLastPathComponent] stringByAppendingPathComponent:
				[@"._" stringByAppendingString:[path lastPathComponent]]];
			break;

			case XADVisibleAppleDoubleForkStyle:
				path=[path stringByAppendingPathExtension:@"rsrc"];
			break;
		}
	}

	XADError error=[self extractEntryWithDictionary:dict as:path forceDirectories:force];

	[pool release];

	return error;
}

-(XADError)extractEntryWithDictionary:(NSDictionary *)dict as:(NSString *)path
{
	return [self extractEntryWithDictionary:dict as:path forceDirectories:NO];
}

-(XADError)extractEntryWithDictionary:(NSDictionary *)dict as:(NSString *)path forceDirectories:(BOOL)force
{
	NSAutoreleasePool *pool=[NSAutoreleasePool new];

	NSNumber *dirnum=[dict objectForKey:XADIsDirectoryKey];
	NSNumber *linknum=[dict objectForKey:XADIsLinkKey];
	NSNumber *resnum=[dict objectForKey:XADIsResourceForkKey];
	BOOL isdir=dirnum&&[dirnum boolValue];
	BOOL islink=linknum&&[linknum boolValue];
	BOOL isres=resnum&&[resnum boolValue];

	// Ask for permission and report that we are starting.
	if(delegate)
	{
		if(![delegate unarchiver:self shouldStartExtractingEntryWithDictionary:dict to:path]) return XADBreakError;
		[delegate unarchiver:self willStartExtractingEntryWithDictionary:dict to:path];
	}

	XADError error=XADNoError;

	if(isres)
	{
		switch(forkstyle)
		{
			case XADIgnoredForkStyle:
			break;

			case XADMacOSXForkStyle:
				if(!isdir)
				error=[self _extractResourceForkEntryWithDictionary:dict asMacForkForFile:path];
			break;

			case XADHiddenAppleDoubleForkStyle:
			case XADVisibleAppleDoubleForkStyle:
				error=[self _extractResourceForkEntryWithDictionary:dict asAppleDoubleFile:path];
			break;

			default:
				// TODO: better error
				error=XADBadParametersError;
			break;
		}
	}
	else if(isdir)
	{
		error=[self _extractDirectoryEntryWithDictionary:dict as:path];
	}
	else if(islink)
	{
		error=[self _extractLinkEntryWithDictionary:dict as:path];
	}
	else
	{
		error=[self _extractFileEntryWithDictionary:dict as:path];
	}

	// Update file attributes
	if(!error)
	{
		error=[self _updateFileAttributesAtPath:path forEntryWithDictionary:dict deferDirectories:!force];
	}

	// Report success or failure
	if(delegate)
	{
		if(error==XADNoError) [delegate unarchiver:self finishedExtractingEntryWithDictionary:dict to:path];
		else [delegate unarchiver:self failedToExtractEntryWithDictionary:dict to:path error:error];
	}

	[pool release];

	return error;
}

static NSInteger SortDirectoriesByDepthAndResource(id entry1,id entry2,void *context)
{
	NSDictionary *dict1=[entry1 objectAtIndex:1];
	NSDictionary *dict2=[entry2 objectAtIndex:1];

	XADPath *path1=[dict1 objectForKey:XADFileNameKey];
	XADPath *path2=[dict2 objectForKey:XADFileNameKey];
	int depth1=[path1 depth];
	int depth2=[path2 depth];
	if(depth1>depth2) return NSOrderedAscending;
	else if(depth1<depth2) return NSOrderedDescending;

	NSNumber *resnum1=[dict1 objectForKey:XADIsResourceForkKey];
	NSNumber *resnum2=[dict2 objectForKey:XADIsResourceForkKey];
	BOOL isres1=resnum1&&[resnum1 boolValue];
	BOOL isres2=resnum2&&[resnum2 boolValue];
	if(!resnum1&&resnum2) return NSOrderedAscending;
	else if(resnum1&&!resnum2) return NSOrderedDescending;

	return NSOrderedSame;
}

-(XADError)finishExtractions
{
	[deferreddirectories sortUsingFunction:SortDirectoriesByDepthAndResource context:NULL];

	NSEnumerator *enumerator=[deferreddirectories objectEnumerator];
	NSArray *entry;
	while(entry=[enumerator nextObject])
	{
		NSString *path=[entry objectAtIndex:0];
		NSDictionary *dict=[entry objectAtIndex:1];

		XADError error=[self _updateFileAttributesAtPath:path forEntryWithDictionary:dict deferDirectories:NO];
		if(error) return error;
	}

	[deferreddirectories removeAllObjects];

	return XADNoError;
}




-(XADError)_extractFileEntryWithDictionary:(NSDictionary *)dict as:(NSString *)destpath
{
	int fh=open([destpath fileSystemRepresentation],O_WRONLY|O_CREAT|O_TRUNC,0666);
	if(fh==-1) return XADOpenFileError;

	XADError err=[self _extractEntryWithDictionary:dict toFileHandle:fh];

	close(fh);

	return err;
}

-(XADError)_extractResourceForkEntryWithDictionary:(NSDictionary *)dict asMacForkForFile:(NSString *)destpath
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
	XADError error;
	const char *crsrcpath=[[destpath stringByAppendingPathComponent:@"..namedfork/rsrc"] fileSystemRepresentation];

	int fh=open(crsrcpath,O_WRONLY|O_CREAT|O_TRUNC,0666);
	if(fh!=-1)
	{
		// If opening the resource fork worked, extract data to it.
		error=[self _extractEntryWithDictionary:dict toFileHandle:fh];
	}
	else
	{
		// If opening the resource fork failed, change permissions on the file and try again.
		struct stat st;
		stat(cpath,&st);
		chmod(cpath,0700);

		int fh=open(crsrcpath,O_WRONLY|O_CREAT|O_TRUNC,0666);
		if(fh==-1) return XADOpenFileError;

		error=[self _extractEntryWithDictionary:dict toFileHandle:fh];

		chmod(cpath,st.st_mode);
	}

	close(fh);

	return error;
}

-(XADError)_extractResourceForkEntryWithDictionary:(NSDictionary *)dict asAppleDoubleFile:(NSString *)destpath
{
	int fh=open([destpath fileSystemRepresentation],O_WRONLY|O_CREAT|O_TRUNC,0666);
	if(fh==-1) return XADOpenFileError;

	uint8_t header[0x32]=
	{
		0x00,0x05,0x16,0x07,0x00,0x02,0x00,0x00,
		0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
		0x00,0x02,
		0x00,0x00,0x00,0x09,0x00,0x00,0x00,0x32,0x00,0x00,0x00,0x20,
		0x00,0x00,0x00,0x02,0x00,0x00,0x00,0x52,0x00,0x00,0x00,0x00,
	};

	off_t size=0;
	NSNumber *sizenum=[dict objectForKey:XADFileSizeKey];
	if(sizenum) size=[sizenum longLongValue];

	CSSetUInt32BE(&header[46],size);
	write(fh,header,sizeof(header));

	NSData *finderinfo=[parser finderInfoForDictionary:dict];
	if([finderinfo length]<32) { close(fh); return XADUnknownError; }
	write(fh,[finderinfo bytes],32);

	XADError error=XADNoError;
	if(size) error=[self _extractEntryWithDictionary:dict toFileHandle:fh];

	close(fh);

	return error;
}

-(XADError)_extractDirectoryEntryWithDictionary:(NSDictionary *)dict as:(NSString *)destpath
{
	return [self _ensureDirectoryExists:destpath];
}

-(XADError)_extractLinkEntryWithDictionary:(NSDictionary *)dict as:(NSString *)destpath
{
	NSString *link=nil;

	if(delegate)
	{
		link=[delegate unarchiver:self linkDestinationForEntryWithDictionary:dict from:destpath];
	}

	if(!link) link=[[parser linkDestinationForDictionary:dict] string];

	if(!link) return XADBadParametersError; // TODO: better error

	struct stat st;
	const char *destcstr=[destpath fileSystemRepresentation];
	if(lstat(destcstr,&st)==0) unlink(destcstr);
	if(symlink([link fileSystemRepresentation],destcstr)!=0) return XADOutputError;

	return XADNoError;
}




-(XADError)_extractEntryWithDictionary:(NSDictionary *)dict toFileHandle:(int)fh
{
	@try
	{
		CSHandle *srchandle=[parser handleForEntryWithDictionary:dict wantChecksum:YES];
		if(!srchandle) [XADException raiseNotSupportedException];

		NSNumber *sizenum=[dict objectForKey:XADFileSizeKey];
		off_t size=0;
		if(sizenum) size=[sizenum longLongValue];

		off_t done=0;
		double updatetime=0;
		uint8_t buf[65536];

		for(;;)
		{
			if(delegate&&[delegate extractionShouldStopForUnarchiver:self]) [XADException raiseExceptionWithXADError:XADBreakError];

			int actual=[srchandle readAtMost:sizeof(buf) toBuffer:buf];
			if(actual&&write(fh,buf,actual)!=actual) [XADException raiseOutputException];

			done+=actual;

			double currtime=XADGetTime();
			if(currtime-updatetime>updateinterval)
			{
				updatetime=currtime;

				off_t progress;
				if(sizenum) progress=(double)done/(double)size;
				else progress=[srchandle estimatedProgress];

				[delegate unarchiver:self extractionProgressForEntryWithDictionary:dict
				fileFraction:progress estimatedTotalFraction:[[parser handle] estimatedProgress]];
			}

			if(actual==0) break;
		}

		if(sizenum&&done!=size) [XADException raiseDecrunchException]; // kind of hacky
		if([srchandle hasChecksum]&&![srchandle isChecksumCorrect]) [XADException raiseChecksumException];
	}
	@catch(id e)
	{
		return [XADException parseException:e];
	}

	return XADNoError;
}




-(XADError)_updateFileAttributesAtPath:(NSString *)path forEntryWithDictionary:(NSDictionary *)dict
deferDirectories:(BOOL)defer
{
	if(defer)
	{
		NSNumber *dirnum=[dict objectForKey:XADIsDirectoryKey];
		if(dirnum&&[dirnum boolValue])
		{
			[deferreddirectories addObject:[NSArray arrayWithObjects:path,dict,nil]];
			return XADNoError;
		}
	}

	const char *cpath=[path fileSystemRepresentation];

	struct stat st;
	if(stat(cpath,&st)!=0) return XADOpenFileError; // TODO: better error

	// If the file does not have write permissions, change this temporarily
	// and remember to change back.
	BOOL changedpermissions=NO;
	if(!(st.st_mode&S_IWUSR))
	{
		chmod(cpath,0700);
		changedpermissions=YES;
	}

	// Handle timestamps.
	NSDate *modification=[dict objectForKey:XADLastModificationDateKey];
	NSDate *access=[dict objectForKey:XADLastAccessDateKey];

	if(modification||access)
	{
		struct timeval times[2]={
			{st.st_atimespec.tv_sec,st.st_atimespec.tv_nsec/1000},
			{st.st_mtimespec.tv_sec,st.st_mtimespec.tv_nsec/1000},
		};

		if(access) times[0]=[access timevalStruct];
		if(modification) times[1]=[modification timevalStruct];

		if(utimes(cpath,times)!=0) return XADUnknownError; // TODO: better error
	}

	// Handle Mac OS specific metadata.
	#ifdef __APPLE__
	NSNumber *type=[dict objectForKey:XADFileTypeKey];
	NSNumber *creator=[dict objectForKey:XADFileCreatorKey];
	NSNumber *finderflags=[dict objectForKey:XADFinderFlagsKey];
	NSDate *creation=[dict objectForKey:XADCreationDateKey];
	// TODO: Handle FinderInfo structure

	if(type||creator||finderflags||creation)
	{
		FSRef ref;
		FSCatalogInfo info;
		if(FSPathMakeRefWithOptions((const UInt8 *)cpath,
		kFSPathMakeRefDoNotFollowLeafSymlink,&ref,NULL)!=noErr) return NO;
		if(FSGetCatalogInfo(&ref,kFSCatInfoFinderInfo|kFSCatInfoCreateDate,&info,NULL,NULL,NULL)!=noErr)
		return XADUnknownError; // TODO: better error

		FileInfo *finfo=(FileInfo *)&info.finderInfo;

		if(type) finfo->fileType=[type unsignedLongValue];
		if(creator) finfo->fileCreator=[creator unsignedLongValue];
		if(finderflags) finfo->finderFlags=[finderflags unsignedShortValue];
		if(creation) info.createDate=[creation UTCDateTime];

		if(FSSetCatalogInfo(&ref,kFSCatInfoFinderInfo|kFSCatInfoCreateDate,&info)!=noErr)
		return XADUnknownError; // TODO: better error
	}
	#endif

	// Handle permissions (or change back to original permissions if they were changed).
	NSNumber *permissions=[dict objectForKey:XADPosixPermissionsKey];
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
				mode&=~(mask|S_ISUID|S_ISGID);
			}
		}

		if(chmod(cpath,mode&~S_IFMT)!=0) return XADUnknownError; // TODO: bette error
	}

	return XADNoError;
}

-(XADError)_ensureDirectoryExists:(NSString *)path
{
	if([path length]==0) return XADNoError;

	const char *cpath=[path fileSystemRepresentation];
	struct stat st;
	if(lstat(cpath,&st)==0)
	{
		if((st.st_mode&S_IFMT)==S_IFDIR) return XADNoError;
		else return XADMakeDirectoryError;
	}
	else
	{
		XADError error=[self _ensureDirectoryExists:[path stringByDeletingLastPathComponent]];
		if(error) return error;

		if(delegate)
		{
			if(![delegate unarchiver:self shouldCreateDirectory:path]) return XADBreakError;
		}

		if(mkdir(cpath,0777)==0) return XADNoError;
		else return XADMakeDirectoryError;
	}
}




-(void)archiveParser:(XADArchiveParser *)parser foundEntryWithDictionary:(NSDictionary *)dict
{
	// TODO: conditionals?
	[self extractEntryWithDictionary:dict];
}

-(BOOL)archiveParsingShouldStop:(XADArchiveParser *)parser
{
	if(!delegate) return NO;
	return [delegate extractionShouldStopForUnarchiver:self];
}

-(void)archiveParserNeedsPassword:(XADArchiveParser *)parser
{
	if(!delegate) return;
	[delegate unarchiverNeedsPassword:self];
}


@end



@implementation NSObject (XADUnarchiverDelegate)

-(void)unarchiverNeedsPassword:(XADUnarchiver *)unarchiver {}

-(NSString *)unarchiver:(XADUnarchiver *)unarchiver pathForExtractingEntryWithDictionary:(NSDictionary *)dict { return nil; }
-(BOOL)unarchiver:(XADUnarchiver *)unarchiver shouldStartExtractingEntryWithDictionary:(NSDictionary *)dict to:(NSString *)path { return YES; }
-(void)unarchiver:(XADUnarchiver *)unarchiver willStartExtractingEntryWithDictionary:(NSDictionary *)dict to:(NSString *)path {}
-(void)unarchiver:(XADUnarchiver *)unarchiver finishedExtractingEntryWithDictionary:(NSDictionary *)dict to:(NSString *)path {}
-(void)unarchiver:(XADUnarchiver *)unarchiver failedToExtractEntryWithDictionary:(NSDictionary *)dict to:(NSString *)path error:(XADError)error {}

-(BOOL)unarchiver:(XADUnarchiver *)unarchiver shouldCreateDirectory:(NSString *)directory { return YES; }
-(BOOL)unarchiver:(XADUnarchiver *)unarchiver shouldExtractArchiveEntryWithDictionary:(NSDictionary *)dict to:(NSString *)path { return NO; }

-(NSString *)unarchiver:(XADUnarchiver *)unarchiver linkDestinationForEntryWithDictionary:(NSDictionary *)dict from:(NSString *)path { return nil; }
//-(XADAction)unarchiver:(XADUnarchiver *)unarchiver creatingDirectoryDidFailForEntry:(int)n;

-(BOOL)extractionShouldStopForUnarchiver:(XADUnarchiver *)unarchiver { return NO; }
-(void)unarchiver:(XADUnarchiver *)unarchiver extractionProgressForEntryWithDictionary:(NSDictionary *)dict
fileFraction:(double)fileprogress estimatedTotalFraction:(double)totalprogress {}

@end




static double XADGetTime()
{
	struct timeval tv;
	gettimeofday(&tv,NULL);
	return (double)tv.tv_sec+(double)tv.tv_usec/1000000.0;
}
