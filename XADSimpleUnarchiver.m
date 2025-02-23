/*
 * XADSimpleUnarchiver.m
 *
 * Copyright (c) 2017-present, MacPaw Inc. All rights reserved.
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
 * MA 02110-1301  USA
 */
#import "XADSimpleUnarchiver.h"
#import "XADPlatform.h"
#import "XADException.h"

#ifdef __APPLE__
#include <sys/xattr.h>
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
	return [self initWithArchiveParser:archiveparser entries:nil];
}

-(id)initWithArchiveParser:(XADArchiveParser *)archiveparser entries:(NSArray *)entryarray
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
		@"\\.(part[0-9]+\\.rar|tar\\.gz|tar\\.bz2|tar\\.lzma|tar\\.xz|tar\\.Z|warc\\.gz|warc\\.bz2|warc\\.lzma|warc\\.xz|warc\\.Z|sit\\.hqx)$"
		options:REG_ICASE])
		{
			enclosingdir=[[[name stringByDeletingPathExtension]
			stringByDeletingPathExtension] retain];
		}
		else
		{
			enclosingdir=[[name stringByDeletingPathExtension] retain];
		}

		// TODO: Check if we accidentally create a package. Seems impossible, though.

		extractsubarchives=YES;
		removesolo=YES;

		overwrite=NO;
		rename=NO;
		skip=NO;

		copydatetoenclosing=NO;
		copydatetosolo=NO;
		resetsolodate=NO;
		propagatemetadata=YES;

		regexes=nil;
		indices=nil;

		if(entryarray) entries=[[NSMutableArray alloc] initWithArray:entryarray];
		else entries=[NSMutableArray new];

		reasonsforinterest=[NSMutableArray new];
		renames=[NSMutableDictionary new];
		resourceforks=[NSMutableSet new];

		NSString *archivename=[parser filename];
		if(archivename) metadata=[[XADPlatform readCloneableMetadataFromPath:archivename] retain];
		else metadata=nil;

		unpackdestination=nil;
		finaldestination=nil;
		overridesoloitem=nil;

		toplevelname=nil;
		lookslikesolo=NO;

		numextracted=0;
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
	[renames release];
	[resourceforks release];
	[metadata release];

	[unpackdestination release];
	[finaldestination release];
	[overridesoloitem release];

	[toplevelname release];

	[super dealloc];
}

-(XADArchiveParser *)archiveParser
{
	if(subunarchiver) return [subunarchiver archiveParser];
	else return parser;
}

-(XADArchiveParser *)outerArchiveParser { return parser; }
-(XADArchiveParser *)innerArchiveParser { return [subunarchiver archiveParser]; }

-(NSArray *)reasonsForInterest { return reasonsforinterest; }

@synthesize delegate;

-(NSString *)password { return [parser password]; }
-(void)setPassword:(NSString *)password
{
	[parser setPassword:password];
	[[subunarchiver archiveParser] setPassword:password];
}

@synthesize destination;
-(void)setDestination:(NSString *)destpath
{
	if(destpath!=destination)
	{
		[destination release];
		destination=[destpath copy];
	}
}

@synthesize enclosingDirectoryName = enclosingdir;
-(void)setEnclosingDirectoryName:(NSString *)dirname
{
	if(dirname!=enclosingdir)
	{
		[enclosingdir release];
		enclosingdir=[dirname copy];
	}
}

@synthesize removesEnclosingDirectoryForSoloItems = removesolo;

@synthesize alwaysOverwritesFiles = overwrite;

@synthesize alwaysRenamesFiles = rename;

@synthesize alwaysSkipsFiles = skip;

@synthesize extractsSubArchives = extractsubarchives;

@synthesize copiesArchiveModificationTimeToEnclosingDirectory = copydatetoenclosing;

@synthesize copiesArchiveModificationTimeToSoloItems = copydatetosolo;

@synthesize resetsDateForSoloItems = resetsolodate;

@synthesize propagatesRelevantMetadata = propagatemetadata;

-(XADForkStyle)macResourceForkStyle { return [unarchiver macResourceForkStyle]; }
-(void)setMacResourceForkStyle:(XADForkStyle)style
{
	[unarchiver setMacResourceForkStyle:style];
	[subunarchiver setMacResourceForkStyle:style];
}

-(BOOL)preservesPermissions { return [unarchiver preservesPermissions]; }
-(void)setPreservesPermissions:(BOOL)preserveflag
{
	[unarchiver setPreservesPermissions:preserveflag];
	[subunarchiver setPreservesPermissions:preserveflag];
}
-(void)setPreserevesPermissions:(BOOL)preserveflag
{
	self.preservesPermissions = preserveflag;
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

-(void)addIndexFilter:(NSInteger)index
{
	if(!indices) indices=[NSMutableIndexSet new];
	[indices addIndex:index];
}

-(void)setIndices:(NSIndexSet *)newindices
{
	if(!indices) indices=[NSMutableIndexSet new];
	[indices removeAllIndexes];
	[indices addIndexes:newindices];
}




-(off_t)predictedTotalSize { return [self predictedTotalSizeIgnoringUnknownFiles:NO]; }

-(off_t)predictedTotalSizeIgnoringUnknownFiles:(BOOL)ignoreunknown
{
	off_t total=0;

	for(NSDictionary *dict in entries)
	{
		NSNumber *num=[dict objectForKey:XADFileSizeKey];
		if(!num)
		{
			if(ignoreunknown) continue;
			else return -1;
		}

		total+=[num longLongValue];
	}

	return total;
}




@synthesize numberOfItemsExtracted = numextracted;

@synthesize wasSoloItem = lookslikesolo;

@synthesize actualDestination = finaldestination;

-(NSString *)soloItem
{
	if(lookslikesolo)
	{
		if(overridesoloitem) return overridesoloitem;

		NSArray *keys=[renames allKeys];
		if([keys count]==1)
		{
			NSString *key=[keys objectAtIndex:0];
			id value=[[renames objectForKey:key] objectForKey:@"."];
			if(value!=[NSNull null]) return value;
		}
	}
	return nil;
}

-(NSString *)createdItem
{
	if(!enclosingdir) return nil;
	else if(lookslikesolo && removesolo) return [self soloItem];
	else return finaldestination;
}

-(NSString *)createdItemOrActualDestination
{
	if(lookslikesolo && enclosingdir && removesolo)
	{
		NSString *soloitem=[self soloItem];
		if(soloitem) return soloitem;
		else return @".";
	}
	else
	{
		return finaldestination;
	}
}

-(BOOL)parseWithError:(NSError**)error
{
	if(entries.count) {
		if (error) {
			*error = [NSError errorWithDomain:XADErrorDomain code:XADErrorBadParameters userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"You can not call parseAndUnarchive twice", NSLocalizedDescriptionKey, nil]];
		}
		
		return NO;
	}

	// Run parser to find archive entries.
	parser.delegate = self;
	BOOL parseSuccess=[parser parseWithError:error];
	if (!parseSuccess) {
		return NO;
	}

	if (extractsubarchives) {
		// Check if we have a single entry, which is an archive.
		if (entries.count==1) {
			NSDictionary *entry=[entries objectAtIndex:0];
			NSNumber *archnum=[entry objectForKey:XADIsArchiveKey];
			BOOL isarc=archnum&&archnum.boolValue;
			if(isarc) return [self _setupSubArchiveForEntryWithDataFork:entry resourceFork:nil error:error];
		}

		// Check if we have two entries, which are data and resource forks
		// of the same archive.
		if (entries.count==2) {
			NSDictionary *first=[entries objectAtIndex:0];
			NSDictionary *second=[entries objectAtIndex:1];
			XADPath *name1=[first objectForKey:XADFileNameKey];
			XADPath *name2=[second objectForKey:XADFileNameKey];
			NSNumber *archnum1=[first objectForKey:XADIsArchiveKey];
			NSNumber *archnum2=[second objectForKey:XADIsArchiveKey];
			BOOL isarc1=archnum1&&archnum1.boolValue;
			BOOL isarc2=archnum2&&archnum2.boolValue;

			if ([name1 isEqual:name2] && (isarc1||isarc2)) {
				NSNumber *resnum=[first objectForKey:XADIsResourceForkKey];
				NSDictionary *datafork,*resourcefork;
				if (resnum&&resnum.boolValue) {
					datafork=second;
					resourcefork=first;
				} else {
					datafork=first;
					resourcefork=second;
				}

				// TODO: Handle resource forks for archives that require them.
				NSNumber *archnum=[datafork objectForKey:XADIsArchiveKey];
				if(archnum&&archnum.boolValue) {
					return [self _setupSubArchiveForEntryWithDataFork:datafork resourceFork:resourcefork error:error];
				}
			}
		}
	}

	return YES;
}


-(XADError)parse
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
			BOOL isarc=archnum&&[archnum boolValue];
			if(isarc) return [self _setupSubArchiveForEntryWithDataFork:entry resourceFork:nil];
		}

		// Check if we have two entries, which are data and resource forks
		// of the same archive.
		if([entries count]==2)
		{
			NSDictionary *first=[entries objectAtIndex:0];
			NSDictionary *second=[entries objectAtIndex:1];
			XADPath *name1=[first objectForKey:XADFileNameKey];
			XADPath *name2=[second objectForKey:XADFileNameKey];
			NSNumber *archnum1=[first objectForKey:XADIsArchiveKey];
			NSNumber *archnum2=[second objectForKey:XADIsArchiveKey];
			BOOL isarc1=archnum1&&[archnum1 boolValue];
			BOOL isarc2=archnum2&&[archnum2 boolValue];

			if([name1 isEqual:name2] && (isarc1||isarc2))
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
					datafork=first;
					resourcefork=second;
				}

				// TODO: Handle resource forks for archives that require them.
				NSNumber *archnum=[datafork objectForKey:XADIsArchiveKey];
				if(archnum&&[archnum boolValue]) return [self _setupSubArchiveForEntryWithDataFork:datafork resourceFork:resourcefork];
			}
		}
	}

	return XADErrorNone;
}

-(XADError)_setupSubArchiveForEntryWithDataFork:(NSDictionary *)datadict resourceFork:(NSDictionary *)resourcedict
{
	// Create unarchiver.
	XADError error;
	subunarchiver=[[unarchiver unarchiverForEntryWithDictionary:datadict
	resourceForkDictionary:resourcedict wantChecksum:YES error:&error] retain];
	if(!subunarchiver)
	{
		if(error) return error;
		else return XADErrorSubArchive;
	}
	return XADErrorNone;
}


-(BOOL)_setupSubArchiveForEntryWithDataFork:(NSDictionary *)datadict resourceFork:(NSDictionary *)resourcedict error:(NSError**)outError
{
	// Create unarchiver.
	NSError *error = nil;
	subunarchiver=[[unarchiver unarchiverForEntryWithDictionary:datadict
	resourceForkDictionary:resourcedict wantChecksum:YES nserror:&error]
	retain];
	if (!subunarchiver) {
		if (outError) {
			if (!error) {
				*outError = [NSError errorWithDomain:XADErrorDomain code:XADErrorSubArchive userInfo:nil];
			} else {
				*outError = error;
			}
		}
		
		return NO;
	}
	return YES;
}


-(XADError)unarchive
{
	if(subunarchiver) return [self _unarchiveSubArchive];
	else return [self _unarchiveRegularArchive];
}

-(XADError)_unarchiveRegularArchive
{
	// Calculate total size and check if there is a single top-level item.
	totalsize=0;
	totalprogress=0;

	for(NSDictionary *entry in entries)
	{
		NSNumber *dirnum=[entry objectForKey:XADIsDirectoryKey];
		BOOL isdir=dirnum && [dirnum boolValue];

		// If we have not given up on calculating a total size, and this
		// is not a directory, add the size of the current item.
		if(totalsize>=0 && !isdir)
		{
			NSNumber *size=[entry objectForKey:XADFileSizeKey];

			// Disable accurate progress calculation if any sizes are unknown.
			if(size != nil) totalsize+=[size longLongValue];
			else totalsize=-1;
		}
		

		// Run test for single top-level items.
		[self _testForSoloItems:entry];
	}

	// Figure out actual destination to write to.
	NSString *destpath;
	BOOL shouldremove=removesolo && lookslikesolo;
	if(enclosingdir && !shouldremove)
	{
		if(destination) destpath=[destination stringByAppendingPathComponent:enclosingdir];
		else destpath=enclosingdir;

		// Check for collision.
		destpath=[self _checkPath:destpath forEntryWithDictionary:nil deferred:NO];
		if(!destpath) return XADErrorNone;
	}
	else
	{
		if(destination) destpath=destination;
		else destpath=@".";
	}

	unpackdestination=[destpath copy];
	finaldestination=[destpath copy];

	// Run unarchiver on all entries.
	unarchiver.delegate = self;

	for(NSDictionary *entry in entries)
	{
		if([self _shouldStop]) return XADErrorBreak;

		if(totalsize>=0) currsize=[[entry objectForKey:XADFileSizeKey] longLongValue];

		XADError error=[unarchiver extractEntryWithDictionary:entry];
		if(error==XADErrorBreak) return XADErrorBreak;

		if(totalsize>=0) totalprogress+=currsize;
	}

	if([self _shouldStop]) return XADErrorBreak;

	// If we ended up extracting nothing, give up.
	if(!numextracted) return XADErrorNone;

	return [self _finalizeExtraction];
}

-(XADError)_unarchiveSubArchive
{
	XADError error;

	// Figure out actual destination to write to.
	NSString *destpath,*originaldest=nil;
	if(enclosingdir)
	{
		if(destination) destpath=[destination stringByAppendingPathComponent:enclosingdir];
		else destpath=enclosingdir;

		if(removesolo)
		{
			// If there is a possibility we might remove the enclosing directory
			// later, do not handle collisions until after extraction is finished.
			// For now, just pick a unique name if necessary.
			if([XADPlatform fileExistsAtPath:destpath])
			{
				originaldest=destpath;
				destpath=[XADSimpleUnarchiver _findUniquePathForOriginalPath:destpath];
			}
		}
		else
		{
			// Check for collision.
			destpath=[self _checkPath:destpath forEntryWithDictionary:nil deferred:NO];
			if(!destpath) return XADErrorNone;
		}
	}
	else
	{
		if(destination) destpath=destination;
		else destpath=@".";
	}

	unpackdestination=[destpath copy];

	// Disable accurate progress calculation.
	totalsize=-1;

	// Parse sub-archive and automatically unarchive its contents.
	// At this stage, files are guaranteed to be written to unpackdestination
	// and never outside it.
	subunarchiver.delegate = self;
	error=[subunarchiver parseAndUnarchive];

	// Check if the caller wants to give up.
	if(error==XADErrorBreak) return XADErrorBreak;
	if([self _shouldStop]) return XADErrorBreak;

	// If we ended up extracting nothing, give up.
	if(!numextracted) return error;

	// If we extracted a single item, remember its path.
	NSString *soloitem=[self soloItem];

	// If we are removing the enclosing directory for solo items, check
	// how many items were extracted, and handle collisions and moving files.
	if(enclosingdir && removesolo)
	{
		if(lookslikesolo)
		{
			// Only one top-level item was unpacked. Move it to the parent
			// directory and remove the enclosing directory.
			NSString *itemname=[soloitem lastPathComponent];

			// To avoid trouble, first rename the enclosing directory
			// to something unique.
			NSString *enclosingpath=destpath;
			NSString *newenclosingpath=[XADPlatform uniqueDirectoryPathWithParentDirectory:destination];
			[XADPlatform moveItemAtPath:enclosingpath toPath:newenclosingpath];

			NSString *newitempath=[newenclosingpath stringByAppendingPathComponent:itemname];

			// Figure out the new path, and check it for collisions.
			NSString *finalitempath;
			if(destination) finalitempath=[destination stringByAppendingPathComponent:itemname];
			else finalitempath=itemname;

			finalitempath=[self _checkPath:finalitempath forEntryWithDictionary:nil deferred:YES];
			if(!finalitempath)
			{
				// In case skipping was requested, delete everything and give up.
				[XADPlatform removeItemAtPath:newenclosingpath];
				numextracted=0;
				return error;
			}

			// Move the item into place and delete the enclosing directory.
			if(![self _recursivelyMoveItemAtPath:newitempath toPath:finalitempath overwrite:YES])
				error=XADErrorFileExists; // TODO: Better error handling.

			[XADPlatform removeItemAtPath:newenclosingpath];

			// Remember where the item ended up.
			finaldestination=[[finalitempath stringByDeletingLastPathComponent] retain];
			soloitem=finalitempath;

		}
		else
		{
			// Multiple top-level items were unpacked, so we keep the enclosing
			// directory, but we need to check if there was a collision while
			// creating it, and handle this.
			if(originaldest)
			{
				NSString *enclosingpath=destpath;
				NSString *newenclosingpath=[self _checkPath:originaldest forEntryWithDictionary:nil deferred:YES];
				if(!newenclosingpath)
				{
					// In case skipping was requested, delete everything and give up.
					[XADPlatform removeItemAtPath:enclosingpath];
					numextracted=0;
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
					if(![self _recursivelyMoveItemAtPath:enclosingpath toPath:newenclosingpath overwrite:YES])
						error=XADErrorFileExists; // TODO: Better error handling.
				}

				// Remember where the items ended up.
				finaldestination=[newenclosingpath copy];
			}
			else
			{
				// Remember where the items ended up.
				finaldestination=[destpath copy];
			}
		}
	}
	else
	{
		// Remember where the items ended up.
		finaldestination=[destpath copy];
	}

	// Save the final path to the solo item, if any.
	overridesoloitem=[soloitem copy];

	if(error) return error;

	return [self _finalizeExtraction];
}

-(XADError)_finalizeExtraction
{
	XADError error=[unarchiver finishExtractions];
	if(error) return error;

	// Update date of the enclosing directory (or single item), if requested.
	if(enclosingdir)
	{
		NSString *archivename=[[unarchiver archiveParser] filename];
		if(archivename)
		{
			if(lookslikesolo && removesolo)
			{
				// We are dealing with a solo item removed from the enclosing directory.
				NSString *soloitem=[self soloItem];
				if(copydatetosolo) [XADPlatform copyDateFromPath:archivename toPath:soloitem];
				else if(resetsolodate) [XADPlatform resetDateAtPath:soloitem];
			}
			else
			{
				// We are dealing with an enclosing directory.
				if(copydatetoenclosing) [XADPlatform copyDateFromPath:archivename toPath:finaldestination];
			}
		}
	}

	return XADErrorNone;
}

-(void)_testForSoloItems:(NSDictionary *)entry
{
	// If we haven't already discovered there are multiple top-level items, check
	// if this one has the same first first path component as the earlier ones.
	if(lookslikesolo || !toplevelname)
	{
		NSString *safepath=[[entry objectForKey:XADFileNameKey] sanitizedPathString];
		NSArray *components=[safepath pathComponents];

		NSString *firstcomp;
		if([components count]>0) firstcomp=[components objectAtIndex:0];
		else firstcomp=@"";

		if(!toplevelname)
		{
			toplevelname=[firstcomp copy];
			lookslikesolo=YES;
		}
		else
		{
			if(![toplevelname isEqual:firstcomp]) lookslikesolo=NO;
		}
	}
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
	if ([delegate respondsToSelector:@selector(simpleUnarchiverNeedsPassword:)]) {
		[delegate simpleUnarchiverNeedsPassword:self];
	}
}

-(void)archiveParser:(XADArchiveParser *)parser findsFileInterestingForReason:(NSString *)reason;
{
	[reasonsforinterest addObject:reason];
}

-(void)unarchiverNeedsPassword:(XADUnarchiver *)unarchiver
{
	if ([delegate respondsToSelector:@selector(simpleUnarchiverNeedsPassword:)]) {
		[delegate simpleUnarchiverNeedsPassword:self];
	}
}

-(BOOL)unarchiver:(XADUnarchiver *)currunarchiver shouldExtractEntryWithDictionary:(NSDictionary *)dict suggestedPath:(NSString **)pathptr
{
	// If this is a sub-archive, we need to run the test for solo top-level items.
	if(currunarchiver==subunarchiver) [self _testForSoloItems:dict];

	// Decode name.
	XADPath *xadpath=[dict objectForKey:XADFileNameKey];
	NSString *encodingname=nil;
	if(delegate && ![xadpath encodingIsKnown])
	{
		encodingname=[delegate simpleUnarchiver:self encodingNameForXADString:xadpath];
		if(!encodingname) return NO;
	}

	NSString *safefilename;
	if(encodingname) safefilename=[xadpath sanitizedPathStringWithEncodingName:encodingname];
	else safefilename=[xadpath sanitizedPathString];

	// Make sure to update path for resource forks.
	safefilename=[currunarchiver adjustPathString:safefilename forEntryWithDictionary:dict];

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
				if([regex matchesString:safefilename]) found=YES;
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
	NSString *path=unpackdestination;
	NSArray *components=[safefilename pathComponents];
	int numcomponents=[components count];
	for(int i=0;i<numcomponents;i++)
	{
		NSString *component=[components objectAtIndex:i];
		NSMutableDictionary *pathdict=[parent objectForKey:component];
		if(!pathdict)
		{
			// This path has not been encountered yet. First, build a
			// path based on the current component and the parent's path.
			path=[path stringByAppendingPathComponent:component];

			// Check it for collisions.
			path=[self _checkPath:path forEntryWithDictionary:dict deferred:NO];

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

	if([delegate respondsToSelector:@selector(simpleUnarchiver:shouldExtractEntryWithDictionary:to:)])
	{
		// If we have a delegate, ask it if we should extract.
		if(![delegate simpleUnarchiver:self shouldExtractEntryWithDictionary:dict to:path]) return NO;

		// Check if the user wants to extract the entry to his own filehandle.
		// In such case, call into the lower-level API to run the extraction
		// and return without doing further work.
		CSHandle *handle=nil;
		if ([delegate respondsToSelector:@selector(simpleUnarchiver:outputHandleForEntryWithDictionary:)]) {
			handle=[delegate simpleUnarchiver:self outputHandleForEntryWithDictionary:dict];
		}
		if(handle)
		{
			[unarchiver runExtractorWithDictionary:dict outputHandle:handle];
			return NO;
		}
	}

	// Otherwise, just extract.
	return YES;
}

-(void)unarchiver:(XADUnarchiver *)unarch willExtractEntryWithDictionary:(NSDictionary *)dict to:(NSString *)path
{
	// If we are writing OS X or HFV resource forks, keep a list of which resource
	// forks have been extracted, for the collision tests in checkPath.
	XADForkStyle style=[unarch macResourceForkStyle];
	if(style==XADForkStyleMacOSX || style==XADForkStyleHFVExplorerAppleDouble)
	{
		NSNumber *resnum=[dict objectForKey:XADIsResourceForkKey];
		if(resnum && [resnum boolValue]) [resourceforks addObject:path];
	}

	if ([delegate respondsToSelector:@selector(simpleUnarchiver:willExtractEntryWithDictionary:to:)]) {
		[delegate simpleUnarchiver:self willExtractEntryWithDictionary:dict to:path];
	}
}

-(void)unarchiver:(XADUnarchiver *)unarchiver didExtractEntryWithDictionary:(NSDictionary *)dict to:(NSString *)path error:(XADError)error
{
	numextracted++;

	if(propagatemetadata && metadata) [XADPlatform writeCloneableMetadata:metadata toPath:path];
	
	if ([delegate respondsToSelector:@selector(simpleUnarchiver:didExtractEntryWithDictionary:to:error:)]) {
		[delegate simpleUnarchiver:self didExtractEntryWithDictionary:dict to:path error:error];
	}
}

-(BOOL)unarchiver:(XADUnarchiver *)unarchiver shouldCreateDirectory:(NSString *)directory
{
	return YES;
}

-(void)unarchiver:(XADUnarchiver *)unarchiver didCreateDirectory:(NSString *)directory {
    if(propagatemetadata && metadata) {
        [XADPlatform writeCloneableMetadata:metadata toPath:directory];
    }
}

-(BOOL)unarchiver:(XADUnarchiver *)unarchiver shouldDeleteFileAndCreateDirectory:(NSString *)directory
{
	// If a resource fork entry for a directory was accidentally extracted
	// as a file, which can sometimes happen with particularly broken Zip files,
	// overwrite it.
	if([resourceforks containsObject:directory]) return YES;
	else return NO;
}

-(NSString *)unarchiver:(XADUnarchiver *)unarchiver destinationForLink:(XADString *)link from:(NSString *)path
{
	if(!delegate) return nil;

	NSString *encodingname;
	if ([delegate respondsToSelector:@selector(simpleUnarchiver:encodingNameForXADString:)]) {
		encodingname=[delegate simpleUnarchiver:self encodingNameForXADString:link];
	} else {
		encodingname=[link encodingName];
	}
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

	// If we receive a bogus file size ratio, give up and show estimated progress instead,
	// as we have probably been fed a broken Zip file with 32 bit overflow.
	if(fileratio>1) totalsize=-1;

	if(totalsize>=0)
	{
		// If the total size is known, report exact progress.
		off_t fileprogress=fileratio*currsize;
		if ([delegate respondsToSelector:@selector(simpleUnarchiver:extractionProgressForEntryWithDictionary:fileProgress:of:totalProgress:of:)]) {
			[delegate simpleUnarchiver:self extractionProgressForEntryWithDictionary:dict
						  fileProgress:fileprogress of:currsize
						 totalProgress:totalprogress+fileprogress of:totalsize];
		}
	}
	else
	{
		// If the total size is not known, report estimated progress.
		if ([delegate respondsToSelector:@selector(simpleUnarchiver:estimatedExtractionProgressForEntryWithDictionary:fileProgress:totalProgress:)]) {
			[delegate simpleUnarchiver:self estimatedExtractionProgressForEntryWithDictionary:dict
						  fileProgress:fileratio totalProgress:totalratio];
		}
	}
}

-(void)unarchiver:(XADUnarchiver *)unarchiver findsFileInterestingForReason:(NSString *)reason
{
	[reasonsforinterest addObject:reason];
}

-(BOOL)_shouldStop
{
	if(!([delegate respondsToSelector:@selector(extractionShouldStopForSimpleUnarchiver:)])) return NO;
	if(shouldstop) return YES;

	return shouldstop=[delegate extractionShouldStopForSimpleUnarchiver:self];
}




-(NSString *)_checkPath:(NSString *)path forEntryWithDictionary:(NSDictionary *)dict deferred:(BOOL)deferred
{
	// If set to always overwrite, just return the path without further checking.
	if(overwrite) return path;

	// Check for collision.
	if([XADPlatform fileExistsAtPath:path])
	{
		// When writing OS X data forks, some collisions will happen. Try
		// to handle these.
		#ifdef __APPLE__
		if(dict && [self macResourceForkStyle]==XADForkStyleMacOSX)
		{
			NSNumber *resnum=[dict objectForKey:XADIsResourceForkKey];
			if(resnum && [resnum boolValue])
			{
				// If this entry is a resource fork, check if the resource fork
				// size is 0. If so, do not consider this a collision.
				const char *cpath=[path fileSystemRepresentation];
				size_t ressize=getxattr(cpath,XATTR_RESOURCEFORK_NAME,NULL,0,0,XATTR_NOFOLLOW);

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

		// HFV Explorer style forks always create dummy data forks, which can cause collisions.
		// Just kludge this by ignoring collisions for data forks if a resource was written earlier.
		if(dict && [self macResourceForkStyle]==XADForkStyleHFVExplorerAppleDouble)
		{
			NSNumber *resnum=[dict objectForKey:XADIsResourceForkKey];
			if(!resnum || ![resnum boolValue])
			{
				NSString *forkpath=[[path stringByDeletingLastPathComponent] stringByAppendingPathComponent:
				[@"%" stringByAppendingString:[path lastPathComponent]]];

				if([resourceforks containsObject:forkpath]) return path;
			}
		}

		// If set to always skip, just return nil.
		if(skip) return nil;

		NSString *unique=[XADSimpleUnarchiver _findUniquePathForOriginalPath:path];

		if(rename)
		{
			// If set to always rename, just return the alternate path.
			return unique;
		}
		else if(delegate)
		{
			// If we have a delegate, ask it.
			if (deferred && [delegate respondsToSelector:@selector(simpleUnarchiver:deferredReplacementPathForOriginalPath:suggestedPath:)]) {
				return [delegate simpleUnarchiver:self
		   deferredReplacementPathForOriginalPath:path
									suggestedPath:unique];
			} else if ([delegate respondsToSelector:@selector(simpleUnarchiver:replacementPathForEntryWithDictionary:originalPath:suggestedPath:)]) {
				return [delegate simpleUnarchiver:self
			replacementPathForEntryWithDictionary:dict
									 originalPath:path suggestedPath:unique];
			} else {
				return nil;
			}
		}
		else
		{
			// By default, skip file.
			return nil;
		}
	}
	else return path;
}

-(BOOL)_recursivelyMoveItemAtPath:(NSString *)src toPath:(NSString *)dest overwrite:(BOOL)overwritethislevel
{
	// Check path unless we are sure we are overwriting, and skip if requested.
	if(!overwritethislevel) dest=[self _checkPath:dest forEntryWithDictionary:nil deferred:YES];
	if(!dest) return YES;

	BOOL isdestdir;
	if([XADPlatform fileExistsAtPath:dest isDirectory:&isdestdir])
	{
		BOOL issrcdir;
		if(![XADPlatform fileExistsAtPath:src isDirectory:&issrcdir]) return NO;

		if(issrcdir&&isdestdir)
		{
			// If both source and destinaton are directories, iterate over the
			// contents and recurse.
			NSArray *files=[XADPlatform contentsOfDirectoryAtPath:src];
			for(NSString *file in files)
			{
				NSString *newsrc=[src stringByAppendingPathComponent:file];
				NSString *newdest=[dest stringByAppendingPathComponent:file];
				BOOL res=[self _recursivelyMoveItemAtPath:newsrc toPath:newdest overwrite:NO];
				if(!res) return NO; // TODO: Should this try to move the remaining items?
			}
			return YES;
		}
		else if(!issrcdir&&!isdestdir)
		{
			// If both are files, remove any existing file, then move.
			[XADPlatform removeItemAtPath:dest];
			return [XADPlatform moveItemAtPath:src toPath:dest];
		}
		else
		{
			// Can't overwrite a file with a directory or vice versa.
			return NO;
		}
	}
	else
	{
		return [XADPlatform moveItemAtPath:src toPath:dest];
	}
}

+(NSString *)_findUniquePathForOriginalPath:(NSString *)path
{
	return [self _findUniquePathForOriginalPath:path reservedPaths:nil];
}

+(NSString *)_findUniquePathForOriginalPath:(NSString *)path reservedPaths:(NSSet *)reserved
{
	NSString *base=[path stringByDeletingPathExtension];
	NSString *extension=[path pathExtension];
	if([extension length]) extension=[@"." stringByAppendingString:extension];

	NSString *dest=path;
	int n=1;

	while([XADPlatform fileExistsAtPath:dest] || (reserved&&[reserved containsObject:dest]))
	dest=[NSString stringWithFormat:@"%@-%d%@",base,n++,extension];

	return dest;
}

@end



