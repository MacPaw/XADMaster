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
	id olddelegate=[parser delegate];
	[parser setDelegate:self];

	@try
	{
		[parser parse];
	}
	@catch(id e)
	{
		[parser setDelegate:olddelegate];
		return [XADException parseException:e];
	}

	[parser setDelegate:olddelegate];

	return [self finishExtractions];
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
	NSNumber *archivenum=[dict objectForKey:XADIsArchiveKey];
	BOOL isdir=dirnum&&[dirnum boolValue];
	BOOL islink=linknum&&[linknum boolValue];
	BOOL isres=resnum&&[resnum boolValue];
	BOOL isarchive=archivenum&&[archivenum boolValue];

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

	XADError error=[self _ensureDirectoryExists:[path stringByDeletingLastPathComponent]];
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




-(XADError)_extractFileEntryWithDictionary:(NSDictionary *)dict as:(NSString *)destpath
{
	CSHandle *fh;
	@try { fh=[CSFileHandle fileHandleForWritingAtPath:destpath]; }
	@catch(id e) { return XADOpenFileError; }

	XADError err=[self _extractEntryWithDictionary:dict toHandle:fh];

	[fh close];

	return err;
}

-(XADError)_extractResourceForkEntryWithDictionary:(NSDictionary *)dict asAppleDoubleFile:(NSString *)destpath
{
	// AppleDouble format referenced from:
	// http://www.opensource.apple.com/source/Libc/Libc-391.2.3/darwin/copyfile.c

	CSHandle *fh;
	@try { fh=[CSFileHandle fileHandleForWritingAtPath:destpath]; }
	@catch(id e) { return XADOpenFileError; }

	// AppleDouble header template.
	uint8_t header[0x32]=
	{
		/*  0 */ 0x00,0x05,0x16,0x07, 0x00,0x02,0x00,0x00,
		/*  8 */ 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
		/* 24 */ 0x00,0x02,
		/* 26 */ 0x00,0x00,0x00,0x09, 0x00,0x00,0x00,0x32, 0x00,0x00,0x00,0x00,
		/* 38 */ 0x00,0x00,0x00,0x02, 0x00,0x00,0x00,0x00, 0x00,0x00,0x00,0x00,
		/* 50 */
	};

	NSDictionary *extattrs=[parser extendedAttributesForDictionary:dict];

	// Calculate FinderInfo and extended attributes size field.
	int numattributes=0,attributeentrysize=0,attributedatasize=0;

	// Sort keys and iterate over them.
	NSArray *keys=[[extattrs allKeys] sortedArrayUsingSelector:@selector(compare:)];
	NSEnumerator *enumerator=[keys objectEnumerator];
	NSString *key;
	while((key=[enumerator nextObject]))
	{
		// Ignore FinderInfo.
		if([key isEqual:@"com.apple.FinderInfo"]) continue;

 		NSData *data=[extattrs objectForKey:key];
		int namelen=[key lengthOfBytesUsingEncoding:NSUTF8StringEncoding]+1;
		if(namelen>128) continue; // Skip entries with too long names.

		numattributes++;
		attributeentrysize+=(11+namelen+3)&~3; // Aligned to 4 bytes.
		attributedatasize+=[data length];
	}

	// Set FinderInfo size field and resource fork offset field.
	if(numattributes)
	{
		CSSetUInt32BE(&header[34],32+38+attributeentrysize+attributedatasize);
		CSSetUInt32BE(&header[42],50+32+38+attributeentrysize+attributedatasize);
	}
	else
	{
		CSSetUInt32BE(&header[34],32);
		CSSetUInt32BE(&header[42],50+32);
	}

	// Set resource fork size field.
	off_t ressize=0;
	NSNumber *sizenum=[dict objectForKey:XADFileSizeKey];
	if(sizenum) ressize=[sizenum longLongValue];
	CSSetUInt32BE(&header[46],ressize);

	// Write AppleDouble header.
	[fh writeBytes:sizeof(header) fromBuffer:header];

	// Write FinderInfo structure.
	NSData *finderinfo=[extattrs objectForKey:@"com.apple.FinderInfo"];
	if(finderinfo)
	{
		if([finderinfo length]<32) return XADUnknownError;
		[fh writeBytes:32 fromBuffer:[finderinfo bytes]];
	}
	else
	{
		uint8_t emptyfinderinfo[32]={ 0x00 };
		[fh writeBytes:32 fromBuffer:emptyfinderinfo];
	}

	// Write extended attributes if needed.
	if(numattributes)
	{
		// Attributes section header template.
		uint8_t attributesheader[38]=
		{
			/*  0 */ 0x00,0x00,
			/*  2 */  'A', 'T', 'T', 'R', 0x00,0x00,0x00,0x00,
			/* 10 */ 0x00,0x00,0x00,0x00, 0x00,0x00,0x00,0x00,
			/* 18 */ 0x00,0x00,0x00,0x00, 0x00,0x00,0x00,0x00,
			/* 26 */ 0x00,0x00,0x00,0x00, 0x00,0x00,0x00,0x00,
			/* 34 */ 0x00,0x00, 0x00,0x00,
			/* 38 */
		};

		int datastart=50+32+38+attributeentrysize;

		// Set header fields.
		CSSetUInt32BE(&attributesheader[10],datastart+attributedatasize); // total_size
		CSSetUInt32BE(&attributesheader[14],datastart); // data_start
		CSSetUInt32BE(&attributesheader[18],attributedatasize); // data_length
		CSSetUInt16BE(&attributesheader[36],numattributes); // num_attrs

		// Write attributes section header.
		[fh writeBytes:sizeof(attributesheader) fromBuffer:attributesheader];

		// Write attribute entries.
		int currdataoffset=datastart;
		NSEnumerator *enumerator=[keys objectEnumerator];
		NSString *key;
		while((key=[enumerator nextObject]))
		{
			// Ignore FinderInfo.
			if([key isEqual:@"com.apple.FinderInfo"]) continue;

			NSData *data=[extattrs objectForKey:key];
			int namelen=[key lengthOfBytesUsingEncoding:NSUTF8StringEncoding]+1;
			if(namelen>128) continue; // Skip entries with too long names.

			// Attribute entry header template.
			uint8_t entryheader[11]=
			{
				/*  0 */ 0x00,0x00,0x00,0x00, 0x00,0x00,0x00,0x00,
				/*  8 */ 0x00,0x00, namelen,
				/* 11 */ 
			};

			// Set entry header fields.
			CSSetUInt32BE(&entryheader[0],currdataoffset); // offset
			CSSetUInt32BE(&entryheader[4],[data length]); // length

			// Write entry header.
			[fh writeBytes:sizeof(entryheader) fromBuffer:entryheader];

			// Write name.
			char namebytes[namelen];
			[key getCString:namebytes maxLength:namelen encoding:NSUTF8StringEncoding];
			[fh writeBytes:namelen fromBuffer:namebytes];

			// Calculate and write padding.
			int padbytes=(-(namelen+11))&3;
			uint8_t zerobytes[4]={ 0x00 };
			[fh writeBytes:padbytes fromBuffer:zerobytes];

			// Update data pointer.
			currdataoffset+=[data length];
		}

		// Write attribute data.
		enumerator=[keys objectEnumerator];
		while((key=[enumerator nextObject]))
		{
			// Ignore FinderInfo.
			if([key isEqual:@"com.apple.FinderInfo"]) continue;

			NSData *data=[extattrs objectForKey:key];
			int namelen=[key lengthOfBytesUsingEncoding:NSUTF8StringEncoding]+1;
			if(namelen>128) continue; // Skip entries with too long names.

			[fh writeData:data];
		}
	}

	// Write resource fork.
	XADError error=XADNoError;
	if(ressize) error=[self _extractEntryWithDictionary:dict toHandle:fh];

	[fh close];

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

	return [self _createPlatformSpecificLinkToPath:link from:destpath];
}

-(XADError)_extractArchiveEntryWithDictionary:(NSDictionary *)dict to:(NSString *)destpath name:(NSString *)filename
{
	@try
	{
		CSHandle *srchandle=[parser handleForEntryWithDictionary:dict wantChecksum:YES];
		if(!srchandle) return XADNotSupportedError;

		XADArchiveParser *subparser=[XADArchiveParser archiveParserForHandle:srchandle name:filename]; // TODO: provide a name?
		if(!subparser) return XADSubArchiveError;

		XADUnarchiver *unarchiver=[XADUnarchiver unarchiverForArchiveParser:subparser];

		[unarchiver setDelegate:delegate];
		[unarchiver setDestination:destpath];
		[unarchiver setMacResourceForkStyle:forkstyle];
		[unarchiver setPreserevesPermissions:preservepermissions];
		[unarchiver setUpdateInterval:updateinterval];

		[delegate unarchiver:self willExtractArchiveEntryWithDictionary:dict
		withUnarchiver:unarchiver to:destpath];

		XADError error=[unarchiver parseAndUnarchive];

		[delegate unarchiver:self didExtractArchiveEntryWithDictionary:dict
		withUnarchiver:unarchiver to:destpath error:error];

		return error;
	}
	@catch(id e)
	{
		return [XADException parseException:e];
	}
	return XADUnknownError; // Kludge to keep gcc quiet
}



-(XADError)_extractEntryWithDictionary:(NSDictionary *)dict toHandle:(CSHandle *)fh
{
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
			if(delegate&&[delegate extractionShouldStopForUnarchiver:self]) return XADBreakError;

			int actual=[srchandle readAtMost:sizeof(buf) toBuffer:buf];
			if(actual)
			{
				// TODO: combine the except parsing for input and output
				@try { [fh writeBytes:actual fromBuffer:buf]; }
				@catch(id e) { return XADOutputError; }
			}

			done+=actual;

			double currtime=_XADUnarchiverGetTime();
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

-(NSString *)unarchiver:(XADUnarchiver *)unarchiver linkDestinationForEntryWithDictionary:(NSDictionary *)dict from:(NSString *)path { return nil; }
//-(XADAction)unarchiver:(XADUnarchiver *)unarchiver creatingDirectoryDidFailForEntry:(int)n;

-(BOOL)extractionShouldStopForUnarchiver:(XADUnarchiver *)unarchiver { return NO; }
-(void)unarchiver:(XADUnarchiver *)unarchiver extractionProgressForEntryWithDictionary:(NSDictionary *)dict
fileFraction:(double)fileprogress estimatedTotalFraction:(double)totalprogress {}

@end

