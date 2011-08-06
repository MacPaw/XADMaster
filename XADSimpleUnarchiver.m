#import "XADSimpleUnarchiver.h"
#import "XADException.h"

#ifdef __APPLE__
#include <sys/xattr.h>
#endif
#ifndef __MINGW32__
#include <unistd.h>
#endif

@implementation XADSimpleUnarchiver

+(XADSimpleUnarchiver *)simpleUnarchiverForPath:(NSString *)path
{
	return [self simpleUnarchiverForPath:path error:NULL];
}

+(XADSimpleUnarchiver *)simpleUnarchiverForPath:(NSString *)path error:(XADError *)errorptr;
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
		unarchiver=[[XADUnarchiver alloc] initWithArchiveParser:archiveparser];
		subunarchiver=nil;

		delegate=nil;
		shouldstop=NO;

		destination=nil;

		NSString *name=[archiveparser name];
		if([name matchedByPattern:
		@"\\.(part[0-9]+\\.rar|tar\\.gz|tar\\.bz2|tar\\.lzma|sit\\.hqx)$"
		options:REG_ICASE])
		{
			enclosingdir=[[[name stringByDeletingPathExtension]
			stringByDeletingPathExtension] retain];
		}
		else
		{
			enclosingdir=[[name stringByDeletingPathExtension] retain];
		}

		extractsubarchives=YES;
		removesolo=YES;

		overwrite=NO;
		rename=NO;
		skip=NO;

		updateenclosing=NO;
		updatesolo=NO;
		propagatemetadata=YES;

		regexes=nil;
		indices=nil;

		entries=[NSMutableArray new];
		reasonsforinterest=[NSMutableArray new];
		renames=[NSMutableDictionary new];
		resourceforks=[NSMutableSet new];

		actualdestination=nil;
		finaldestination=nil;

		#ifdef __APPLE__
		quarantinedict=NULL;
		FSRef ref;
		if(LSSetItemAttribute)
		if(CFURLGetFSRef((CFURLRef)[NSURL fileURLWithPath:[parser filename]],&ref))
		{
			LSCopyItemAttribute(&ref,kLSRolesAll,kLSItemQuarantineProperties,
			(CFTypeRef*)&quarantinedict);
		}
		#endif
	}

	return self;
}

-(void)dealloc
{
	[parser release];
	[unarchiver release];
	[subunarchiver release];

	[destination release];
	[enclosingdir release];

	[regexes release];
	[indices release];

	[entries release];
	[reasonsforinterest release];
	[resourceforks release];
	[renames release];

	[actualdestination release];
	[finaldestination release];

	#ifdef __APPLE__
	if(quarantinedict) CFRelease(quarantinedict);
	#endif

	[super dealloc];
}

-(XADArchiveParser *)archiveParser
{
	if(subunarchiver) return [subunarchiver archiveParser];
	else return parser;
}

-(NSArray *)reasonsForInterest { return reasonsforinterest; }

-(id)delegate { return delegate; }
-(void)setDelegate:(id)newdelegate { delegate=newdelegate; }

-(NSString *)password { return [parser password]; }
-(void)setPassword:(NSString *)password
{
	[parser setPassword:password];
	[[subunarchiver archiveParser] setPassword:password];
}

-(NSString *)destination { return destination; }
-(void)setDestination:(NSString *)destpath
{
	if(destpath!=destination)
	{
		[destination release];
		destination=[destpath retain];
	}
}

-(NSString *)enclosingDirectoryName { return enclosingdir; }
-(void)setEnclosingDirectoryName:(NSString *)dirname
{
	if(dirname!=enclosingdir)
	{
		[enclosingdir release];
		enclosingdir=[dirname retain];
	}
}

-(BOOL)removesEnclosingDirectoryForSoloItems { return removesolo; }
-(void)setRemovesEnclosingDirectoryForSoloItems:(BOOL)removeflag { removesolo=removeflag; }

-(BOOL)alwaysOverwritesFiles { return overwrite; }
-(void)setAlwaysOverwritesFiles:(BOOL)overwriteflag { overwrite=overwriteflag; }

-(BOOL)alwaysRenamesFiles { return rename; }
-(void)setAlwaysRenamesFiles:(BOOL)renameflag { rename=renameflag; }

-(BOOL)alwaysSkipsFiles { return skip; }
-(void)setAlwaysSkipsFiles:(BOOL)skipflag { skip=skipflag; }

-(BOOL)updatesEnclosingDirectoryModificationTime { return updateenclosing; }
-(void)setUpdatesEnclosingDirectoryModificationTime:(BOOL)modificationflag { updateenclosing=modificationflag; }

-(BOOL)updatesSoloItemModificationTime { return updatesolo; }
-(void)setUpdatesSoloItemModificationTime:(BOOL)modificationflag { updatesolo=modificationflag; }

-(BOOL)extractsSubArchives { return extractsubarchives; }
-(void)setExtractsSubArchives:(BOOL)extractflag { extractsubarchives=extractflag; }

-(BOOL)propagatesRelevantMetadata { return propagatemetadata; }
-(void)setPropagatesRelevantMetadata:(BOOL)propagateflag { propagatemetadata=propagateflag; }

-(int)macResourceForkStyle { return [unarchiver macResourceForkStyle]; }
-(void)setMacResourceForkStyle:(int)style
{
	[unarchiver setMacResourceForkStyle:style];
	[subunarchiver setMacResourceForkStyle:style];
}

-(BOOL)preservesPermissions { return [unarchiver preservesPermissions]; }
-(void)setPreserevesPermissions:(BOOL)preserveflag
{
	[unarchiver setPreserevesPermissions:preserveflag];
	[subunarchiver setPreserevesPermissions:preserveflag];
}

-(double)updateInterval { return [unarchiver updateInterval]; }
-(void)setUpdateInterval:(double)interval
{
	[unarchiver setUpdateInterval:interval];
	[subunarchiver setUpdateInterval:interval];
}

-(void)addGlobFilter:(NSString *)wildcard
{
	// TODO: SOMEHOW correctly handle case sensitivity!
	NSString *pattern=[XADRegex patternForGlob:wildcard];
	#if defined(__APPLE__) || defined(__MINGW32__)
	[self addRegexFilter:[XADRegex regexWithPattern:pattern options:REG_ICASE]];
	#else
	[self addRegexFilter:[XADRegex regexWithPattern:pattern options:0]];
	#endif
}

-(void)addRegexFilter:(XADRegex *)regex
{
	if(!regexes) regexes=[NSMutableArray new];
	[regexes addObject:regex];
}

-(void)addIndexFilter:(int)index
{
	if(!indices) indices=[NSMutableIndexSet new];
	[indices addIndex:index];
}

-(NSString *)actualDestinationPath { return finaldestination; }




-(XADError)parseAndUnarchive
{
	if([entries count]) [NSException raise:NSInternalInconsistencyException format:@"You can not call parseAndUnarchive twice"];

	// Run parser to find archive entries.
	[parser setDelegate:self];
	XADError error=[parser parseWithoutExceptions];
	if(error) return error;

	if(extractsubarchives)
	{
		// Check if we have a single entry, which is an archive.
		if([entries count]==1)
		{
			NSDictionary *entry=[entries objectAtIndex:0];
			NSNumber *archnum=[entry objectForKey:XADIsArchiveKey];
			if(archnum&&[archnum boolValue]) return [self _handleSubArchiveWithEntry:entry];
		}

		// Check if we have two entries, which are data and resource forks
		// of the same archive.
		if([entries count]==2)
		{
			NSDictionary *first=[entries objectAtIndex:0];
			NSDictionary *second=[entries objectAtIndex:1];
			XADPath *name1=[first objectForKey:XADFileNameKey];
			XADPath *name2=[second objectForKey:XADFileNameKey];

			if([name1 isEqual:name2])
			{
				NSNumber *resnum=[first objectForKey:XADIsResourceForkKey];
				NSDictionary *datafork,*resourcefork;
				if(resnum&&[resnum boolValue])
				{
					datafork=second;
					resourcefork=first;
				}
				else
				{
					datafork=second;
					resourcefork=first;
				}

				// TODO: Handle resource forks for archives that require them.
				NSNumber *archnum=[datafork objectForKey:XADIsArchiveKey];
				if(archnum&&[archnum boolValue]) return [self _handleSubArchiveWithEntry:datafork];
			}
		}
	}

	return [self _handleRegularArchive];
}

-(XADError)_handleRegularArchive
{
	NSEnumerator *enumerator;
	NSDictionary *entry;

	// Calculate total size and, if needed, check if there is a single
	// top-level item.
	totalsize=0;
	totalprogress=0;

	XADString *toplevelname=nil;
	BOOL shouldremove=removesolo;

	enumerator=[entries objectEnumerator];
	while((entry=[enumerator nextObject]))
	{
		// If we have not given up on calculating a total size, add the size
		// of the current item.
		if(totalsize>=0)
		{
			NSNumber *size=[entry objectForKey:XADFileSizeKey];

			// Disable accurate progress calculation if any sizes are unknown.
			if(size) totalsize+=[size longLongValue];
			else totalsize=-1;
		}

		// If we are interested in single top-level items and haven't already
		// discovered there are multiple, check if this one has the same first
		// first path component as the earlier ones.
		if(shouldremove)
		{
			XADString *firstcomp=[[entry objectForKey:XADFileNameKey] firstPathComponent];
			if(!toplevelname)
			{
				toplevelname=firstcomp;
			}
			else
			{
				if(![toplevelname isEqual:firstcomp]) shouldremove=NO;
			}
		}
	}

	// Figure out actual destination to write to.
	NSString *destpath;
	if(enclosingdir && !shouldremove)
	{
		if(destination) destpath=[destination stringByAppendingPathComponent:enclosingdir];
		else destpath=enclosingdir;

		// Check for collision.
		destpath=[self _checkPath:destpath forEntryWithDictionary:nil deferred:NO];
		if(!destpath) return XADBreakError;
	}
	else
	{
		if(destination) destpath=destination;
		else destpath=@".";
	}

	actualdestination=[destpath retain];
	finaldestination=[destpath retain];

	// Run unarchiver on all entries.
	XADError lasterror=XADNoError;

	[unarchiver setDelegate:self];

	enumerator=[entries objectEnumerator];
	while((entry=[enumerator nextObject]))
	{
		if(totalsize>=0) currsize=[[entry objectForKey:XADFileSizeKey] longLongValue];

		XADError error=[unarchiver extractEntryWithDictionary:entry];
		if(error!=XADNoError && error!=XADBreakError) lasterror=error;

		if(totalsize>=0) totalprogress+=currsize;
	}

	XADError error=[unarchiver finishExtractions];
	if(error) lasterror=error;

	return lasterror;
}

-(XADError)_handleSubArchiveWithEntry:(NSDictionary *)entry
{
	XADError error;

	// Figure out actual destination to write to.
	NSString *destpath,*originaldest;
	BOOL needsolocheck=NO;
	if(enclosingdir)
	{
		if(destination) destpath=[destination stringByAppendingPathComponent:enclosingdir];
		else destpath=enclosingdir;

		if(removesolo)
		{
			// If there is a possibility we might remove the enclosing directory
			// later, do not handle collisions until after extraction is finished.
			// For now, just pick a unique name if necessary.
			if([[NSFileManager defaultManager] fileExistsAtPath:destpath])
			{
				originaldest=destpath;
				destpath=[self _findUniquePathForCollidingPath:destpath];
			}
			needsolocheck=YES;
		}
		else
		{
			// Check for collision.
			destpath=[self _checkPath:destpath forEntryWithDictionary:nil deferred:NO];
			if(!destpath) return XADBreakError;
		}
	}
	else
	{
		if(destination) destpath=destination;
		else destpath=@".";
	}

	actualdestination=[destpath retain];

	// Create unarchiver.
	subunarchiver=[[unarchiver unarchiverForEntryWithDictionary:entry
	wantChecksum:YES error:&error] retain];
	if(!subunarchiver)
	{
		if(error) return error;
		else return XADSubArchiveError;
	}

	// Disable accurate progress calculation.
	totalsize=-1;

	// Parse sub-archive and automatically unarchive its contents.
	[subunarchiver setDelegate:self];
	error=[subunarchiver parseAndUnarchive];

	// If we are removing the enclosing directory for solo items, check
	// how many items were extracted, and handle collision and moving files.
	if(needsolocheck)
	{
		NSString *enclosingpath=destpath;
		NSArray *files=[self _contentsOfDirectoryAtPath:enclosingpath];
		if([files count]==1)
		{
			// Only one top-level item was unpacked. Move it to the parent
			// directory and remove the enclosing directory.
			NSString *itempath=[files objectAtIndex:0];
			NSString *itemname=[itempath lastPathComponent];

			// To avoid trouble, first rename the enclosing directory
			// to something unique.
			NSString *newenclosingpath=[self _uniqueDirectoryNameWithParentDirectory:destination];
			NSString *newitempath=[newenclosingpath stringByAppendingPathComponent:itemname];
			[self _moveItemAtPath:enclosingpath toPath:newenclosingpath];

			// Figure out the new path, and check it for collisions.
			NSString *finalitempath=[destination stringByAppendingPathComponent:itemname];
			finalitempath=[self _checkPath:finalitempath forEntryWithDictionary:nil deferred:YES];
			if(!finalitempath)
			{
				// In case skipping was requested, delete everything and give up.
				[self _removeItemAtPath:newenclosingpath];
				return error;
			}

			// Move the item into place and delete the enclosing directory.
			if(![self _recursivelyMoveItemAtPath:newitempath toPath:finalitempath])
			error=XADFileExistsError; // TODO: Better error handling.

			[self _removeItemAtPath:newenclosingpath];

			// Remember where the item ended up.
			finaldestination=[[finalitempath stringByDeletingLastPathComponent] retain];
		}
		else if([files count]>1)
		{
			// Multiple top-level items were unpacked, so we keep the enclosing
			// directory, but we need to check if there was a collision while
			// creating it, and handle this.
			if(originaldest)
			{
				NSString *newenclosingpath=[self _checkPath:originaldest forEntryWithDictionary:nil deferred:YES];
				if(!newenclosingpath)
				{
					// In case skipping was requested, delete everything and give up.
					[self _removeItemAtPath:enclosingpath];
					return error;
				}
				else if([newenclosingpath isEqual:enclosingpath])
				{
					// If the selected new path is equal to the earlier picked
					// unique path, nothing needs to be done.
				}
				else
				{
					// Otherwise, move the directory at the unique path to the
					// new location selected. This may end up being the original
					// path that caused the collision.
					if(![self _recursivelyMoveItemAtPath:enclosingpath toPath:newenclosingpath])
					error=XADFileExistsError; // TODO: Better error handling.
				}

				// Remember where the items ended up.
				finaldestination=[newenclosingpath retain];
			}
			else
			{
				// Remember where the items ended up.
				finaldestination=[destpath retain];
			}
		}
	}
	else
	{
		// Remember where the items ended up.
		finaldestination=[destpath retain];
	}

	[self _finalizeExtraction];

	return error;
}

-(void)_finalizeExtraction
{
/*		BOOL alwayscreatepref=[[NSUserDefaults standardUserDefaults] integerForKey:@"createFolder"]==2;
		BOOL copydatepref=[[NSUserDefaults standardUserDefaults] integerForKey:@"folderModifiedDate"]==2;
		BOOL changefilespref=[[NSUserDefaults standardUserDefaults] boolForKey:@"changeDateOfFiles"];
		BOOL deletearchivepref=[[NSUserDefaults standardUserDefaults] boolForKey:@"deleteExtractedArchive"];
		BOOL openfolderpref=[[NSUserDefaults standardUserDefaults] boolForKey:@"openExtractedFolder"];

		BOOL singlefile=[files count]==1;

		BOOL makefolder=!singlefile || alwayscreatepref;
		BOOL copydate=(makefolder&&copydatepref)||(!makefolder&&changefilespref&&copydatepref);
		BOOL resetdate=!makefolder&&changefilespref&&!copydatepref;*/

/*		NSString *finaldest;

			// Check if we accidentally created a package.
			if([[NSWorkspace sharedWorkspace] isFilePackageAtPath:finaldest])
			{
				NSString *newfinaldest=[finaldest stringByDeletingPathExtension];

				#if MAC_OS_X_VERSION_MIN_REQUIRED>=1050
				[fm moveItemAtPath:finaldest toPath:newfinaldest error:NULL];
				#else
				[fm movePath:finaldest toPath:newfinaldest handler:nil];
				#endif

				finaldest=newfinaldest;
			}
		}*/

		// Set correct date for extracted directory
/*		if(copydate)
		{
			FSCatalogInfo archiveinfo,newinfo;

			GetCatalogInfoForFilename(archivename,kFSCatInfoContentMod,&archiveinfo);
			newinfo.contentModDate=archiveinfo.contentModDate;
			SetCatalogInfoForFilename(finaldest,kFSCatInfoContentMod,&newinfo);
		}
		else if(resetdate)
		{
			FSCatalogInfo newinfo;

			UCConvertCFAbsoluteTimeToUTCDateTime(CFAbsoluteTimeGetCurrent(),&newinfo.contentModDate);
			SetCatalogInfoForFilename(finaldest,kFSCatInfoContentMod,&newinfo);
		}*/
}




-(void)archiveParser:(XADArchiveParser *)parser foundEntryWithDictionary:(NSDictionary *)dict
{
	[entries addObject:dict];
}

-(BOOL)archiveParsingShouldStop:(XADArchiveParser *)parser
{
	return [self _shouldStop];
}

-(void)archiveParserNeedsPassword:(XADArchiveParser *)parser
{
	[delegate simpleUnarchiverNeedsPassword:self];
}

-(void)archiveParser:(XADArchiveParser *)parser findsFileInterestingForReason:(NSString *)reason;
{
	[reasonsforinterest addObject:reason];
}

-(void)unarchiverNeedsPassword:(XADUnarchiver *)unarchiver
{
	[delegate simpleUnarchiverNeedsPassword:self];
}

-(BOOL)unarchiver:(XADUnarchiver *)unarch shouldExtractEntryWithDictionary:(NSDictionary *)dict suggestedPath:(NSString **)pathptr
{
	// Decode name.
	XADPath *xadpath=[[dict objectForKey:XADFileNameKey] safePath];
	NSString *encodingname=nil;
	if(delegate && ![xadpath encodingIsKnown])
	{
		encodingname=[delegate simpleUnarchiver:self encodingNameForXADPath:xadpath];
		if(!encodingname) return NO;
	}

	NSString *filename;
	if(encodingname) filename=[xadpath stringWithEncodingName:encodingname];
	else filename=[xadpath string];

	// Apply filters.
	if(delegate)
	{
		// If any regex filters have been added, require that one matches.
		if(regexes)
		{
			BOOL found=NO;

			NSEnumerator *enumerator=[regexes objectEnumerator];
			XADRegex *regex;
			while(!found && (regex=[enumerator nextObject]))
			{
				if([regex matchesString:filename]) found=YES;
			}

			if(!found) return NO;
		}

		// If any index filters have been added, require that one matches.
		if(indices)
		{
			NSNumber *indexnum=[dict objectForKey:XADIndexKey];
			int index=[indexnum intValue];
			if(![indices containsIndex:index]) return NO;
		}
	}

	// Walk through the path, and check if any parts that have not already been
	// encountered collide, and cache results in the path hierarchy.
	NSMutableDictionary *parent=renames;
	NSString *path=actualdestination;
	NSArray *components=[xadpath pathComponents];
	int numcomponents=[components count];
	for(int i=0;i<numcomponents;i++)
	{
		XADString *component=[components objectAtIndex:i];
		NSMutableDictionary *pathdict=[parent objectForKey:component];
		if(!pathdict)
		{
			// This path has not been encountered yet. First, build a
			// path based on the current component and the parent's path.
			NSString *componentstr;
			if(encodingname) componentstr=[component stringWithEncodingName:encodingname];
			else componentstr=[component string];

			path=[path stringByAppendingPathComponent:componentstr];

			// Check it for collisions.
			if(i==numcomponents-1)
			{
				path=[unarch adjustPathString:path forEntryWithDictionary:dict];
				path=[self _checkPath:path forEntryWithDictionary:dict deferred:NO];
			}
			else
			{
				path=[self _checkPath:path forEntryWithDictionary:dict deferred:NO];
			}

			if(path)
			{
				// Store path and dictionary in path hierarchy.
				pathdict=[NSMutableDictionary dictionaryWithObject:path forKey:@"."];
				[parent setObject:pathdict forKey:component];
			}
			else
			{
				// If skipping was requested, store a marker in the path hierarchy
				// for future requests, and skip.
				pathdict=[NSMutableDictionary dictionaryWithObject:[NSNull null] forKey:@"."];
				[parent setObject:pathdict forKey:component];
				return NO;
			}
		}
		else
		{
			path=[pathdict objectForKey:@"."];

			// Check if this path was marked as skipped earlier.
			if((id)path==[NSNull null]) return NO;
		}

		parent=pathdict;
	}

	*pathptr=path;

	// If we have a delegate, ask it if we should extract.
	if(delegate) return [delegate simpleUnarchiver:self shouldExtractEntryWithDictionary:dict to:path];

	// Otherwise, just extract.
	return YES;
}

-(void)unarchiver:(XADUnarchiver *)unarch willExtractEntryWithDictionary:(NSDictionary *)dict to:(NSString *)path
{
	// If we are writing OS X resource forks, keep a list of which resource
	// forks have been extracted, for the collision tests in checkPath.
	if([unarch macResourceForkStyle]==XADMacOSXForkStyle)
	{
		NSNumber *resnum=[dict objectForKey:XADIsResourceForkKey];
		if(resnum && [resnum boolValue]) [resourceforks addObject:path];
	}

	[delegate simpleUnarchiver:self willExtractEntryWithDictionary:dict to:path];
}

-(void)unarchiver:(XADUnarchiver *)unarchiver didExtractEntryWithDictionary:(NSDictionary *)dict to:(NSString *)path error:(XADError)error
{
	#ifdef __APPLE__
	if(propagatemetadata && quarantinedict && LSSetItemAttribute)
	{
		FSRef ref;
		if(CFURLGetFSRef((CFURLRef)[NSURL fileURLWithPath:path],&ref))
		LSSetItemAttribute(&ref,kLSRolesAll,kLSItemQuarantineProperties,quarantinedict);
	}
	#endif

	[delegate simpleUnarchiver:self didExtractEntryWithDictionary:dict to:path error:error];
}

-(NSString *)unarchiver:(XADUnarchiver *)unarchiver destinationForLink:(XADString *)link from:(NSString *)path
{
	if(!delegate) return nil;

	NSString *encodingname=[delegate simpleUnarchiver:self encodingNameForXADString:link];
	if(!encodingname) return nil;

	return [link stringWithEncodingName:encodingname];
}

-(BOOL)extractionShouldStopForUnarchiver:(XADUnarchiver *)unarchiver
{
	return [self _shouldStop];
}

-(void)unarchiver:(XADUnarchiver *)unarchiver extractionProgressForEntryWithDictionary:(NSDictionary *)dict
fileFraction:(double)fileratio estimatedTotalFraction:(double)totalratio
{
	if(!delegate) return;

	if(totalsize>=0)
	{
		// If the total size is known, report exact progress.
		off_t fileprogress=fileratio*currsize;
		[delegate simpleUnarchiver:self extractionProgressForEntryWithDictionary:dict
		fileProgress:fileprogress of:currsize
		totalProgress:totalprogress+fileprogress of:totalsize];
	}
	else
	{
		// If the total size is not known, report estimated progress.
		[delegate simpleUnarchiver:self estimatedExtractionProgressForEntryWithDictionary:dict
		fileProgress:fileratio totalProgress:totalratio];
	}
}

-(void)unarchiver:(XADUnarchiver *)unarchiver findsFileInterestingForReason:(NSString *)reason
{
	[reasonsforinterest addObject:reason];
}





-(NSString *)_checkPath:(NSString *)path forEntryWithDictionary:(NSDictionary *)dict deferred:(BOOL)deferred
{
	// If set to always overwrite, just return the path without furhter checking.
	if(overwrite) return path;

	// Check for collision.
	if([[NSFileManager defaultManager] fileExistsAtPath:path])
	{
		// When writing OS X data forks, some collisions will happen. Try
		// to handle these.
		#ifdef __APPLE__
		if(dict && [self macResourceForkStyle]==XADMacOSXForkStyle)
		{
			const char *cpath=[path fileSystemRepresentation];
			size_t ressize=getxattr(cpath,XATTR_RESOURCEFORK_NAME,NULL,0,0,XATTR_NOFOLLOW);

			NSNumber *resnum=[dict objectForKey:XADIsResourceForkKey];
			if(resnum && [resnum boolValue])
			{
				// If this entry is a resource fork, check if the resource fork
				// size is 0. If so, do not consider this a collision.
				if(ressize==0) return path;
			}
			else
			{
				// If this entry is a data fork, check if we have earlier extracted this
				// file as a resource fork. If so, do not consider this a collision.
				if([resourceforks containsObject:path]) return path;
			}
		}
		#endif

		// If set to always skip, just return nil.
		if(skip) return nil;

		NSString *unique=[self _findUniquePathForCollidingPath:path];

		if(rename)
		{
			// If set to always rename, just return the alternate path.
			return unique;
		}
		else if(delegate)
		{
			// If we have a delegate, ask it.
			if(deferred) return [delegate simpleUnarchiver:self
			deferredReplacementPathForEntryOriginalPath:path
			suggestedPath:unique];
			else return [delegate simpleUnarchiver:self
			replacementPathForEntryWithDictionary:dict
			originalPath:path suggestedPath:unique];
		}
		else
		{
			// By default, skip file.
			return nil;
		}
	}
	else return path;
}

-(NSString *)_uniqueDirectoryNameWithParentDirectory:(NSString *)parent
{
	// TODO: ensure this path is actually unique.
	NSDate *now=[NSDate date];
	int64_t t=[now timeIntervalSinceReferenceDate]*1000000000;

	#ifdef __MINGW32__
	NSString *dirname=[NSString stringWithFormat:@"XADTemp%qd",t];
	#else
	pid_t pid=getpid();
	NSString *dirname=[NSString stringWithFormat:@"XADTemp%qd%d",t,pid];
	#endif

	if(parent) return [parent stringByAppendingPathComponent:dirname];
	else return dirname;
}

-(NSString *)_findUniquePathForCollidingPath:(NSString *)path
{
	NSString *base=[path stringByDeletingPathExtension];
	NSString *extension=[path pathExtension];
	if([extension length]) extension=[@"." stringByAppendingString:extension];

	NSString *dest;
	int n=1;
	do { dest=[NSString stringWithFormat:@"%@-%d%@",base,n++,extension]; }
	while([[NSFileManager defaultManager] fileExistsAtPath:dest]);

	return dest;
}

-(NSArray *)_contentsOfDirectoryAtPath:(NSString *)path
{
	#if MAC_OS_X_VERSION_MIN_REQUIRED>=1050
	return [[NSFileManager defaultManager] contentsOfDirectoryAtPath:path error:NULL];
	#else
	return [[NSFileManager defaultManager] directoryContentsAtPath:path];
	#endif
}

-(BOOL)_moveItemAtPath:(NSString *)src toPath:(NSString *)dest
{
	#if MAC_OS_X_VERSION_MIN_REQUIRED>=1050
	return [[NSFileManager defaultManager] moveItemAtPath:src toPath:dest error:NULL];
	#else
	return [[NSFileManager defaultManager] movePath:src toPath:dest handler:nil];
	#endif
}

-(BOOL)_removeItemAtPath:(NSString *)path
{
	#if MAC_OS_X_VERSION_MIN_REQUIRED>=1050
	return [[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
	#else
	return [[NSFileManager defaultManager] removeFileAtPath:path handler:nil];
	#endif
}

-(BOOL)_recursivelyMoveItemAtPath:(NSString *)src toPath:(NSString *)dest
{
	// Check path, and skip if requested.
	dest=[self _checkPath:dest forEntryWithDictionary:nil deferred:YES];
	if(!dest) return YES;

	BOOL isdestdir;
	if([[NSFileManager defaultManager] fileExistsAtPath:dest isDirectory:&isdestdir])
	{
		BOOL issrcdir;
		if(![[NSFileManager defaultManager] fileExistsAtPath:src isDirectory:&issrcdir]) return NO;

		if(issrcdir&&isdestdir)
		{
			// If both source and destinaton are directories, iterate over the
			// contents and recurse.
			NSArray *files=[self _contentsOfDirectoryAtPath:src];
			NSEnumerator *enumerator=[files objectEnumerator];
			NSString *file;
			while((file=[enumerator nextObject]))
			{
				NSString *newsrc=[src stringByAppendingPathComponent:file];
				NSString *newdest=[dest stringByAppendingPathComponent:file];
				BOOL res=[self _recursivelyMoveItemAtPath:newsrc toPath:newdest];
				if(!res) return NO; // TODO: Should this try to move the remaining items?
			}
			return YES;
		}
		else if(!issrcdir&&!isdestdir)
		{
			// If both are files, remove any existing file, then move.
			[self _removeItemAtPath:dest];
			return [self _moveItemAtPath:src toPath:dest];
		}
		else
		{
			// Can't overwrite a file with a directory or vice versa.
			return NO;
		}
	}
	else
	{
		return [self _moveItemAtPath:src toPath:dest];
	}
}

-(BOOL)_shouldStop
{
	if(!delegate) return NO;
	if(shouldstop) return YES;

	return shouldstop=[delegate extractionShouldStopForSimpleUnarchiver:self];
}

@end



@implementation NSObject (XADSimpleUnarchiverDelegate)

-(void)simpleUnarchiverNeedsPassword:(XADSimpleUnarchiver *)unarchiver {}

-(NSString *)simpleUnarchiver:(XADSimpleUnarchiver *)unarchiver encodingNameForXADPath:(XADPath *)path { return [path encodingName]; }
-(NSString *)simpleUnarchiver:(XADSimpleUnarchiver *)unarchiver encodingNameForXADString:(XADString *)string { return [string encodingName]; }

-(BOOL)simpleUnarchiver:(XADSimpleUnarchiver *)unarchiver shouldExtractEntryWithDictionary:(NSDictionary *)dict to:(NSString *)path { return YES; }
-(void)simpleUnarchiver:(XADSimpleUnarchiver *)unarchiver willExtractEntryWithDictionary:(NSDictionary *)dict to:(NSString *)path {}
-(void)simpleUnarchiver:(XADSimpleUnarchiver *)unarchiver didExtractEntryWithDictionary:(NSDictionary *)dict to:(NSString *)path error:(XADError)error {}

-(NSString *)simpleUnarchiver:(XADSimpleUnarchiver *)unarchiver replacementPathForEntryWithDictionary:(NSDictionary *)dict
originalPath:(NSString *)path suggestedPath:(NSString *)unique { return nil; }
-(NSString *)simpleUnarchiver:(XADSimpleUnarchiver *)unarchiver deferredReplacementPathForEntryOriginalPath:(NSString *)path
suggestedPath:(NSString *)unique { return nil; }

-(BOOL)extractionShouldStopForSimpleUnarchiver:(XADSimpleUnarchiver *)unarchiver { return NO; }

-(void)simpleUnarchiver:(XADSimpleUnarchiver *)unarchiver
extractionProgressForEntryWithDictionary:(NSDictionary *)dict
fileProgress:(off_t)fileprogress of:(off_t)filesize
totalProgress:(off_t)totalprogress of:(off_t)totalsize {}
-(void)simpleUnarchiver:(XADSimpleUnarchiver *)unarchiver
estimatedExtractionProgressForEntryWithDictionary:(NSDictionary *)dict
fileProgress:(double)fileprogress totalProgress:(double)totalprogress {}

@end
