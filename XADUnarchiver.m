#import "XADUnarchiver.h"
#import "CSFileHandle.h"
#import "Progress.h"

@implementation XADUnarchiver

+(XADUnarchiver *)unarchiverForArchiveParser:(XADArchiveParser *)archiveparser
{
	return [[[self alloc] initWithArchiveParser:archiveparser] autorelease];
}

+(XADUnarchiver *)unarchiverForPath:(NSString *)path
{
	return [self unarchiverForPath:path error:NULL];
}

+(XADUnarchiver *)unarchiverForPath:(NSString *)path error:(XADError *)errorptr
{
	XADArchiveParser *archiveparser=[XADArchiveParser archiveParserForPath:path error:errorptr];
	if(!archiveparser) return nil;
	return [[[self alloc] initWithArchiveParser:archiveparser] autorelease];
}

-(id)initWithArchiveParser:(XADArchiveParser *)archiveparser
{
	if((self=[super init]))
	{
		parser=[archiveparser retain];
		destination=nil;
		forkstyle=XADDefaultForkStyle;
		preservepermissions=NO;
		updateinterval=0.1;
		delegate=nil;
		shouldstop=NO;

		deferreddirectories=[NSMutableArray new];
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

-(XADArchiveParser *)archiveParser { return parser; }


-(id)delegate { return delegate; }

-(void)setDelegate:(id)newdelegate { delegate=newdelegate; }

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
	id olddelegate=[parser delegate];

	[parser setDelegate:self];
	XADError error=[parser parseWithoutExceptions];
	[parser setDelegate:olddelegate];
	if(error) return error;

	error=[self finishExtractions];
	if(error) return error;

	error=[parser testChecksumWithoutExceptions];
	if(error) return error;

	return XADNoError;
}

-(void)archiveParser:(XADArchiveParser *)parser foundEntryWithDictionary:(NSDictionary *)dict
{
	//if([self _shouldStop]) return; // Unnecessary - XADArchiveParser handles it.
	[self extractEntryWithDictionary:dict];
}

-(BOOL)archiveParsingShouldStop:(XADArchiveParser *)parser
{
	return [self _shouldStop];
}

-(void)archiveParserNeedsPassword:(XADArchiveParser *)parser
{
	[delegate unarchiverNeedsPassword:self];
}

-(void)archiveParser:(XADArchiveParser *)parser findsFileInterestingForReason:(NSString *)reason
{
	[delegate unarchiver:self findsFileInterestingForReason:reason];
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
		NSString *namestring=[name string];
		if(!namestring) return XADEncodingError;

		if(destination) path=[destination stringByAppendingPathComponent:namestring];
		else path=namestring;
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
	NSNumber *archivenum=[dict objectForKey:XADIsArchiveKey];
	BOOL isdir=dirnum&&[dirnum boolValue];
	BOOL islink=linknum&&[linknum boolValue];
	BOOL isres=resnum&&[resnum boolValue];
	BOOL isarchive=archivenum&&[archivenum boolValue];

	// If we are unpacking a resource fork, we may need to modify the path
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

	// Ask for permission and report that we are starting.
	if(delegate)
	{
		if(![delegate unarchiver:self shouldExtractEntryWithDictionary:dict to:path])
		{
			[pool release];
			return XADBreakError;
		}
		[delegate unarchiver:self willExtractEntryWithDictionary:dict to:path];
	}

	XADError error;
	
	error=[self _ensureDirectoryExists:[path stringByDeletingLastPathComponent]];
	if(error) goto end;

	// Attempt to extract embedded archives if requested.
	if(isarchive&&delegate)
	{
		NSString *unarchiverpath=[path stringByDeletingLastPathComponent];

		if([delegate unarchiver:self shouldExtractArchiveEntryWithDictionary:dict to:unarchiverpath])
		{
			error=[self _extractArchiveEntryWithDictionary:dict to:unarchiverpath name:[path lastPathComponent]];
			// If extraction was attempted, and succeeded for failed, skip everything else.
			// Otherwise, if the archive couldn't be opened, fall through and extract normally.
			if(error!=XADSubArchiveError) goto end;
		}
	}

	// Extract normally.
	if(isres)
	{
		switch(forkstyle)
		{
			case XADIgnoredForkStyle:
			break;

			case XADMacOSXForkStyle:
				if(!isdir)
				error=[self _extractResourceForkEntryWithDictionary:dict asPlatformSpecificForkForFile:path];
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

	// Update file attributes, but not for symlinks.  We might not
	// have permission to update these on the the symlink target,
	// which is one reason why we would need to take care to update
	// the link itself, not the target.  Other utilities like GNU
	// Tar don't seem to update the mtime for symlinks either.
	if(!error&&!islink)
	{
		error=[self _updateFileAttributesAtPath:path forEntryWithDictionary:dict deferDirectories:!force];
	}

	// Report success or failure
	end:
	if(delegate)
	{
		[delegate unarchiver:self didExtractEntryWithDictionary:dict to:path error:error];
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
	if(!isres1&&isres2) return NSOrderedAscending;
	else if(isres1&&!isres2) return NSOrderedDescending;

	return NSOrderedSame;
}

-(XADError)finishExtractions
{
	[deferreddirectories sortUsingFunction:SortDirectoriesByDepthAndResource context:NULL];

	NSEnumerator *enumerator=[deferreddirectories objectEnumerator];
	NSArray *entry;
	while((entry=[enumerator nextObject]))
	{
		NSString *path=[entry objectAtIndex:0];
		NSDictionary *dict=[entry objectAtIndex:1];

		XADError error=[self _updateFileAttributesAtPath:path forEntryWithDictionary:dict deferDirectories:NO];
		if(error) return error;
	}

	[deferreddirectories removeAllObjects];

	return XADNoError;
}


-(XADUnarchiver *)unarchiverForEntryWithDictionary:(NSDictionary *)dict
wantChecksum:(BOOL)checksum error:(XADError *)errorptr
{
	XADArchiveParser *subparser=[XADArchiveParser
	archiveParserForEntryWithDictionary:dict
	archiveParser:parser wantChecksum:checksum error:errorptr];
	if(!subparser) return nil;

	XADUnarchiver *subunarchiver=[XADUnarchiver unarchiverForArchiveParser:subparser];
	[subunarchiver setDelegate:delegate];
	[subunarchiver setDestination:destination];
	[subunarchiver setMacResourceForkStyle:forkstyle];
	[subunarchiver setPreserevesPermissions:preservepermissions];
	[subunarchiver setUpdateInterval:updateinterval];

	return subunarchiver;
}




-(XADError)_extractFileEntryWithDictionary:(NSDictionary *)dict as:(NSString *)destpath
{
	CSHandle *fh;
	@try { fh=[CSFileHandle fileHandleForWritingAtPath:destpath]; }
	@catch(id e) { return XADOpenFileError; }

	XADError err=[self runExtractorWithDictionary:dict outputHandle:fh];

	[fh close];

	return err;
}

-(XADError)_extractDirectoryEntryWithDictionary:(NSDictionary *)dict as:(NSString *)destpath
{
	return [self _ensureDirectoryExists:destpath];
}

-(XADError)_extractLinkEntryWithDictionary:(NSDictionary *)dict as:(NSString *)destpath
{
	XADError error;
	XADString *link=[parser linkDestinationForDictionary:dict error:&error];
	if(!link) return error;

	NSString *linkdest=nil;
	if(delegate) linkdest=[delegate unarchiver:self destinationForLink:link from:destpath];
	if(!linkdest)
	{
		linkdest=[link string];
		if(!linkdest) return XADEncodingError;
	}

	// TODO: handle link safety?

	return [self _createPlatformSpecificLinkToPath:linkdest from:destpath];
}

-(XADError)_extractArchiveEntryWithDictionary:(NSDictionary *)dict to:(NSString *)destpath name:(NSString *)filename
{
	XADError error;
	XADUnarchiver *subunarchiver=[self unarchiverForEntryWithDictionary:dict
	wantChecksum:YES error:&error];
	if(!subunarchiver)
	{
		if(error) return error;
		else return XADSubArchiveError;
	}

	[subunarchiver setDestination:destpath];

	[delegate unarchiver:self willExtractArchiveEntryWithDictionary:dict
	withUnarchiver:subunarchiver to:destpath];

	error=[subunarchiver parseAndUnarchive];

	

	[delegate unarchiver:self didExtractArchiveEntryWithDictionary:dict
	withUnarchiver:subunarchiver to:destpath error:error];

	return error;
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

	return [self _updatePlatformSpecificFileAttributesAtPath:path forEntryWithDictionary:dict];
}

-(XADError)_ensureDirectoryExists:(NSString *)path
{
	if([path length]==0) return XADNoError;

	NSFileManager *manager=[NSFileManager defaultManager];

	BOOL isdir;
	if([manager fileExistsAtPath:path isDirectory:&isdir])
	{
		if(isdir) return XADNoError;
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

		#if MAC_OS_X_VERSION_MIN_REQUIRED>=1050
		if([manager createDirectoryAtPath:path
		withIntermediateDirectories:NO attributes:nil error:NULL]) return XADNoError;
		#else
		if([manager createDirectoryAtPath:path attributes:nil]) return XADNoError;
		#endif
		else return XADMakeDirectoryError;
	}
}



-(XADError)runExtractorWithDictionary:(NSDictionary *)dict outputHandle:(CSHandle *)handle
{
	return [self runExtractorWithDictionary:dict outputTarget:self
	selector:@selector(_outputToHandle:bytes:length:) argument:handle];
}

-(XADError)_outputToHandle:(CSHandle *)handle bytes:(uint8_t *)bytes length:(int)length
{
	// TODO: combine the exception parsing for input and output
	@try { [handle writeBytes:length fromBuffer:bytes]; }
	@catch(id e) { return XADOutputError; }
	return XADNoError;
}

-(XADError)runExtractorWithDictionary:(NSDictionary *)dict
outputTarget:(id)target selector:(SEL)selector argument:(id)argument
{
	XADError (*outputfunc)(id,SEL,id,uint8_t *,int);
	outputfunc=(void *)[target methodForSelector:selector];

	@try
	{
		CSHandle *srchandle=[parser handleForEntryWithDictionary:dict wantChecksum:YES];
		if(!srchandle) return XADNotSupportedError;

		NSNumber *sizenum=[dict objectForKey:XADFileSizeKey];
		off_t size=0;
		if(sizenum) size=[sizenum longLongValue];

		off_t done=0;
		double updatetime=0;
		uint8_t buf[0x40000];

		for(;;)
		{
			if([self _shouldStop]) return XADBreakError;

			int actual=[srchandle readAtMost:sizeof(buf) toBuffer:buf];
			if(actual)
			{
				XADError error=outputfunc(target,selector,argument,buf,actual);
				if(error) return error;
			}

			done+=actual;

			double currtime=_XADUnarchiverGetTime();
			if(currtime-updatetime>updateinterval)
			{
				updatetime=currtime;

				double progress;
				if(sizenum) progress=(double)done/(double)size;
				else progress=[srchandle estimatedProgress];

				[delegate unarchiver:self extractionProgressForEntryWithDictionary:dict
				fileFraction:progress estimatedTotalFraction:[[parser handle] estimatedProgress]];
			}

			if(actual==0) break;
		}

		NSNumber *iscorrupt=[dict objectForKey:XADIsCorruptedKey];
		if(iscorrupt&&[iscorrupt boolValue]) return XADDecrunchError;

		if([srchandle hasChecksum])
		{
			if(![srchandle isChecksumCorrect]) return XADChecksumError;
		}
		else
		{
			if(sizenum&&done!=size) return XADDecrunchError; // kind of hacky
		}
	}
	@catch(id e)
	{
		return [XADException parseException:e];
	}

	return XADNoError;
}

-(BOOL)_shouldStop
{
	if(!delegate) return NO;
	if(shouldstop) return YES;

	return shouldstop=[delegate extractionShouldStopForUnarchiver:self];
}

@end



@implementation NSObject (XADUnarchiverDelegate)

-(void)unarchiverNeedsPassword:(XADUnarchiver *)unarchiver {}

-(NSString *)unarchiver:(XADUnarchiver *)unarchiver pathForExtractingEntryWithDictionary:(NSDictionary *)dict { return nil; }
-(BOOL)unarchiver:(XADUnarchiver *)unarchiver shouldExtractEntryWithDictionary:(NSDictionary *)dict to:(NSString *)path { return YES; }
-(void)unarchiver:(XADUnarchiver *)unarchiver willExtractEntryWithDictionary:(NSDictionary *)dict to:(NSString *)path {}
-(void)unarchiver:(XADUnarchiver *)unarchiver didExtractEntryWithDictionary:(NSDictionary *)dict to:(NSString *)path error:(XADError)error {}

-(BOOL)unarchiver:(XADUnarchiver *)unarchiver shouldCreateDirectory:(NSString *)directory { return YES; }

-(BOOL)unarchiver:(XADUnarchiver *)unarchiver shouldExtractArchiveEntryWithDictionary:(NSDictionary *)dict to:(NSString *)path { return NO; }
-(void)unarchiver:(XADUnarchiver *)unarchiver willExtractArchiveEntryWithDictionary:(NSDictionary *)dict withUnarchiver:(XADUnarchiver *)subunarchiver to:(NSString *)path {}
-(void)unarchiver:(XADUnarchiver *)unarchiver didExtractArchiveEntryWithDictionary:(NSDictionary *)dict withUnarchiver:(XADUnarchiver *)subunarchiver to:(NSString *)path error:(XADError)error {}

-(NSString *)unarchiver:(XADUnarchiver *)unarchiver destinationForLink:(XADString *)link from:(NSString *)path
{
	// Kludge to handle old-style interface.
	if([self respondsToSelector:@selector(unarchiver:linkDestinationForEntryWithDictionary:from:)])
	{
		return [self unarchiver:unarchiver linkDestinationForEntryWithDictionary:
		[NSMutableDictionary dictionaryWithObjectsAndKeys:
			link,XADLinkDestinationKey,
			[NSNumber numberWithBool:YES],XADIsLinkKey,
		nil] from:path];
	}
	return nil;
}

-(BOOL)extractionShouldStopForUnarchiver:(XADUnarchiver *)unarchiver { return NO; }
-(void)unarchiver:(XADUnarchiver *)unarchiver extractionProgressForEntryWithDictionary:(NSDictionary *)dict
fileFraction:(double)fileprogress estimatedTotalFraction:(double)totalprogress {}

-(void)unarchiver:(XADUnarchiver *)unarchiver findsFileInterestingForReason:(NSString *)reason {}

@end

