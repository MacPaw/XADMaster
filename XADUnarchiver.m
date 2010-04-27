#import "XADUnarchiver.h"
#import "Progress.h"

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
		updateinterval=0.1;
		delegate=nil;

		[parser setDelegate:self];
	}
	return self;
}

-(void)dealloc
{
	[parser release];
	[destination release];
	[super dealloc];
}

-(id)delegate { return delegate; }
-(void)setDelegate:(id)newdelegate { delegate=newdelegate; }

//-(NSString *)password;
//-(void)setPassword:(NSString *)password;

//-(NSStringEncoding)encoding;
//-(void)setEncoding:(NSStringEncoding)encoding;

-(NSString *)destination { return destination; }

-(void)setDestination:(NSString *)destinationpath
{
	[destination autorelease];
	destination=[destinationpath retain];
}

-(int)macResourceForkStyle { return forkstyle; }

-(void)setMacResourceForkStyle:(int)style { forkstyle=style; }

-(void)parseAndUnarchive
{
	[parser parse];
}

-(XADError)extractEntryWithDictionary:(NSDictionary *)dict
{
	NSAutoreleasePool *pool=[NSAutoreleasePool new];

	NSNumber *dirnum=[dict objectForKey:XADIsDirectoryKey];
	NSNumber *linknum=[dict objectForKey:XADIsLinkKey];
	NSNumber *resnum=[dict objectForKey:XADIsResourceForkKey];
	BOOL isdir=dirnum&&[dirnum boolValue];
	BOOL islink=linknum&&[linknum boolValue];
	BOOL isres=resnum&&[resnum boolValue];

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
	if(isres)
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

	// Ask for permission and report that we are starting.
	if(delegate)
	{
		if(![delegate unarchiver:self shouldStartExtractingEntryWithDictionary:dict to:path]) return XADBreakError;
		[delegate unarchiver:self willStartExtractingEntryWithDictionary:dict to:path];
	}

	XADError error;

	if(isres)
	{
		switch(forkstyle)
		{
			case XADIgnoredForkStyle:
				error=XADNoError;
			break;

			case XADMacOSXForkStyle:
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
		error=[self _updateFileAttributesAtPath:path forEntryWithDictionary:dict];
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
	[self _ensureFileExists:destpath];

	int fh=open([[destpath stringByAppendingPathComponent:@"..namedfork/rsrc"] fileSystemRepresentation],O_WRONLY|O_CREAT|O_TRUNC,0666);
	if(fh==-1) return XADOpenFileError;

	XADError err=[self _extractEntryWithDictionary:dict toFileHandle:fh];

	close(fh);

	return err;
}

-(XADError)_extractResourceForkEntryWithDictionary:(NSDictionary *)dict asAppleDoubleFile:(NSString *)destpath
{
/*	int fh=open([destpath fileSystemRepresentation],O_WRONLY|O_CREAT|O_TRUNC,0666);
	if(fh==-1) return XADOpenFileError;

	XADError err=[self _extractEntryWithDictionary:dict toFileHandle:fh];

	close(fh);

	return err;*/

	return XADNotSupportedError;
}

-(XADError)_extractDirectoryEntryWithDictionary:(NSDictionary *)dict as:(NSString *)destpath
{
	return [self _ensureDirectoryExists:destpath];
}

-(XADError)_extractLinkEntryWithDictionary:(NSDictionary *)dict as:(NSString *)destpath
{
	XADString *xadlink=[parser linkDestinationForDictionary:dict];
	NSString *link;
	if(![xadlink encodingIsKnown]&&delegate)
	{
/*	....
		// TODO: should there be a better way to deal with encodings?
		NSStringEncoding encoding=[delegate archive:self encodingForData:[xadlink data]
		guess:[xadlink encoding] confidence:[xadlink confidence]];
		link=[xadlink stringWithEncoding:encoding];*/
	}
	else link=[xadlink string];

	if(link)
	{
		struct stat st;
		const char *destcstr=[destpath fileSystemRepresentation];
		if(lstat(destcstr,&st)==0) unlink(destcstr);
		if(symlink([link fileSystemRepresentation],destcstr)!=0) return XADOutputError;

		return XADNoError;
	}
	else return XADBadParametersError;
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
{
	return XADNoError;
}

-(XADError)_ensureFileExists:(NSString *)path
{
	
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
		if([self _ensureDirectoryExists:[path stringByDeletingLastPathComponent]])
		{
			if(!delegate||[delegate unarchiver:self shouldCreateDirectory:path])
			{
				if(mkdir(cpath,0777)==0) return XADNoError;
				else return XADMakeDirectoryError;
			}
			else return XADBreakError;
		}
	}


	return NO;
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




static double XADGetTime()
{
	struct timeval tv;
	gettimeofday(&tv,NULL);
	return (double)tv.tv_sec+(double)tv.tv_usec/1000000.0;
}
