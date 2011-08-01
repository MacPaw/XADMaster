#import "XADSimpleUnarchiver.h"
#import "XADException.h"

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

		regexes=nil;
		indices=nil;

		entries=[NSMutableArray new];
		reasonsforinterest=[NSMutableArray new];
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
-(NSString *)enclosingDirectoryPath
{
	if(destination&&enclosingdir) return [destination stringByAppendingPathComponent:enclosingdir];
	else if(enclosingdir) return enclosingdir;
	else return destination;
}
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

-(BOOL)extractsSubArchives { return extractsubarchives; }
-(void)setExtractsSubArchives:(BOOL)extractflag { extractsubarchives=extractflag; }

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
	[self addRegexFilter:[XADRegex regexWithPattern:pattern options:REG_ICASE]];
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

-(XADError)parseAndUnarchive
{
	if([entries count]) [NSException raise:NSInternalInconsistencyException format:@"You can not call parseAndUnarchive twice"];

	// Run parser to find archive entries.
	[parser setDelegate:self];
	XADError error=[parser parseWithoutExceptions];
	if(error) return error;

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

	return [self _handleRegularArchive];
}

-(XADError)_handleRegularArchive
{
	NSEnumerator *enumerator;
	NSDictionary *entry;

	// Calculate total size.
	totalsize=0;
	totalprogress=0;
	enumerator=[entries objectEnumerator];
	while((entry=[enumerator nextObject]))
	{
		NSNumber *size=[entry objectForKey:XADFileSizeKey];

		// Disable accurate progress calculation if any sizes are unknown.
		if(!size)
		{
			totalsize=-1;
			break;
		}

		totalsize+=[size longLongValue];
	}

	// Run unarchiver on all entries.
	XADError lasterror=XADNoError;

	[unarchiver setDelegate:self];

	enumerator=[entries objectEnumerator];
	while((entry=[enumerator nextObject]))
	{
		if(totalsize>=0) currsize=[[entry objectForKey:XADFileSizeKey] longLongValue];

		XADError error=[unarchiver extractEntryWithDictionary:entry];
		if(error) lasterror=error;

		if(totalsize>=0) totalprogress+=currsize;
	}

	[self _finalizeExtraction];

	return lasterror;
}

-(XADError)_handleSubArchiveWithEntry:(NSDictionary *)entry
{
	XADError error;

	// Create handle for entry.
	CSHandle *handle=[parser handleForEntryWithDictionary:entry
	wantChecksum:YES error:&error];
	if(!handle) return error;

	// Create unarchiver.
	subunarchiver=[unarchiver unarchiverForEntryWithDictionary:entry
	wantChecksum:YES error:&error];
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

	[self _finalizeExtraction];

	return error;
}

-(void)_finalizeExtraction
{
	// TODO: postprocessing. Remove containing dir, propagate quarantine, ...

}




-(BOOL)_shouldStop
{
	if(!delegate) return NO;
	if(shouldstop) return YES;

	return shouldstop=[delegate extractionShouldStopForSimpleUnarchiver:self];
}

-(NSString *)_filenameForEntryWithDictionary:(NSDictionary *)dict
{
	XADString *filename=[dict objectForKey:XADFileNameKey];

	NSString *encodingname=[delegate simpleUnarchiver:self encodingNameForXADString:filename];

	if(encodingname) return [filename stringWithEncodingName:encodingname];
	else return [filename string];
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

-(NSString *)unarchiver:(XADUnarchiver *)unarchiver pathForExtractingEntryWithDictionary:(NSDictionary *)dict
{
	if(!delegate) return nil;

	NSString *filename=[self _filenameForEntryWithDictionary:dict];

	NSString *actualdest=[self enclosingDirectoryPath];
	if(actualdest) return [actualdest stringByAppendingPathComponent:filename];
	else return filename;
}

-(BOOL)unarchiver:(XADUnarchiver *)unarchiver shouldExtractEntryWithDictionary:(NSDictionary *)dict to:(NSString *)path
{
	// Apply filters.
	if(delegate)
	{
		// If any regex filters have been added, require that one matches.
		if(regexes)
		{
			NSString *filename=[self _filenameForEntryWithDictionary:dict];
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

	// Check for collisions unless set to always overwrite.
	if(!overwrite)
	if([[NSFileManager defaultManager] fileExistsAtPath:path])
	{
		NSString *unique=[self _findUniquePathForCollidingPath:path];
		if(rename)
		{
			path=unique;
		}
		else if(delegate)
		{
			path=[delegate simpleUnarchiver:self replacementPathForEntryWithDictionary:dict
			originalPath:path suggestedPath:unique];

			// Cancel extraction if delegate requested it.
			if(!path) return NO;
		}
		else
		{
			return NO;
		}
	}

	if(!delegate) return YES;

	return [delegate simpleUnarchiver:self shouldExtractEntryWithDictionary:dict to:path];
}

-(void)unarchiver:(XADUnarchiver *)unarchiver willExtractEntryWithDictionary:(NSDictionary *)dict to:(NSString *)path
{
	[delegate simpleUnarchiver:self willExtractEntryWithDictionary:dict to:path];
}

-(void)unarchiver:(XADUnarchiver *)unarchiver didExtractEntryWithDictionary:(NSDictionary *)dict to:(NSString *)path error:(XADError)error
{
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

@end



@implementation NSObject (XADSimpleUnarchiverDelegate)

-(void)simpleUnarchiverNeedsPassword:(XADSimpleUnarchiver *)unarchiver {}

-(NSString *)simpleUnarchiver:(XADSimpleUnarchiver *)unarchiver encodingNameForXADString:(XADString *)string { return nil; }

-(NSString *)simpleUnarchiver:self replacementPathForEntryWithDictionary:(NSDictionary *)dict
originalPath:(NSString *)path suggestedPath:(NSString *)unique { return nil; }

-(BOOL)simpleUnarchiver:(XADSimpleUnarchiver *)unarchiver shouldExtractEntryWithDictionary:(NSDictionary *)dict to:(NSString *)path { return YES; }
-(void)simpleUnarchiver:(XADSimpleUnarchiver *)unarchiver willExtractEntryWithDictionary:(NSDictionary *)dict to:(NSString *)path {}
-(void)simpleUnarchiver:(XADSimpleUnarchiver *)unarchiver didExtractEntryWithDictionary:(NSDictionary *)dict to:(NSString *)path error:(XADError)error {}

-(BOOL)extractionShouldStopForSimpleUnarchiver:(XADSimpleUnarchiver *)unarchiver { return NO; }

-(void)simpleUnarchiver:(XADSimpleUnarchiver *)unarchiver
extractionProgressForEntryWithDictionary:(NSDictionary *)dict
fileProgress:(off_t)fileprogress of:(off_t)filesize
totalProgress:(off_t)totalprogress of:(off_t)totalsize {}
-(void)simpleUnarchiver:(XADSimpleUnarchiver *)unarchiver
estimatedExtractionProgressForEntryWithDictionary:(NSDictionary *)dict
fileProgress:(double)fileprogress totalProgress:(double)totalprogress {}

@end
