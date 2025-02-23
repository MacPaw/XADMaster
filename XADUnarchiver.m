/*
 * XADUnarchiver.m
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
#import "XADUnarchiver.h"
#import "XADPlatform.h"
#import "XADAppleDouble.h"
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

+(XADUnarchiver *)unarchiverForPath:(NSString *)path nserror:(NSError **)errorptr
{
	XADArchiveParser *archiveparser=[XADArchiveParser archiveParserForPath:path nserror:errorptr];
	if(!archiveparser) return nil;
	return [[[self alloc] initWithArchiveParser:archiveparser] autorelease];
}

-(id)initWithArchiveParser:(XADArchiveParser *)archiveparser
{
	if((self=[super init]))
	{
		parser=[archiveparser retain];
		destination=nil;
		forkstyle=XADForkStyleDefault;
		preservepermissions=NO;
		updateinterval=0.1;
		delegate=nil;
		shouldstop=NO;

		deferreddirectories=[NSMutableArray new];
		deferredlinks=[NSMutableArray new];
	}
	return self;
}

-(void)dealloc
{
	[parser release];
	[destination release];
	[deferreddirectories release];
	[deferredlinks release];
	[super dealloc];
}

@synthesize archiveParser = parser;


@synthesize delegate;

@synthesize destination;

@synthesize macResourceForkStyle = forkstyle;

@synthesize preservesPermissions = preservepermissions;

@synthesize updateInterval = updateinterval;




-(XADError)parseAndUnarchive
{
	id olddelegate=[parser delegate];

	[parser setDelegate:self];
	XADError error=[parser parseWithoutExceptions];
	[parser setDelegate:olddelegate];
	if(error) return error;

	if([self _shouldStop]) return XADErrorBreak;

	error=[self finishExtractions];
	if(error) return error;

	error=[parser testChecksumWithoutExceptions];
	if(error) return error;

	return XADErrorNone;
}

-(BOOL)parseAndUnarchiveWithError:(NSError**)outErr
{
	id olddelegate=parser.delegate;

	parser.delegate = self;
	BOOL success=[parser parseWithError:outErr];
	parser.delegate = olddelegate;
	if(!success) return NO;

	if(self._shouldStop) {
		if (outErr) {
			*outErr = [NSError errorWithDomain:XADErrorDomain code:XADErrorBreak userInfo:nil];
		}
		return NO;
	}

	
	XADError error=[self finishExtractions];
	if(error) {
		if (outErr) {
			*outErr = [NSError errorWithDomain:XADErrorDomain code:error userInfo:nil];
		}
		return NO;
	}

	success=[parser testChecksumWithError:outErr];
	if(!success) {
		return NO;
	}

	return YES;
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
	if ([delegate respondsToSelector:@selector(unarchiverNeedsPassword:)]) {
		[delegate unarchiverNeedsPassword:self];
	}
}

-(void)archiveParser:(XADArchiveParser *)parser findsFileInterestingForReason:(NSString *)reason
{
	if ([delegate respondsToSelector:@selector(unarchiver:findsFileInterestingForReason:)]) {
		[delegate unarchiver:self findsFileInterestingForReason:reason];
	}
}




-(XADError)extractEntryWithDictionary:(NSDictionary *)dict
{
	return [self extractEntryWithDictionary:dict as:nil forceDirectories:NO];
}

-(XADError)extractEntryWithDictionary:(NSDictionary *)dict forceDirectories:(BOOL)force
{
	return [self extractEntryWithDictionary:dict as:nil forceDirectories:force];
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

	// If we were not given a path, pick one ourselves.
	if(!path)
	{
		XADPath *name=[dict objectForKey:XADFileNameKey];
		NSString *namestring=[name sanitizedPathString];

		if(destination) path=[destination stringByAppendingPathComponent:namestring];
		else path=namestring;

		// Adjust path for resource forks.
		path=[self adjustPathString:path forEntryWithDictionary:dict];
	}

	// Ask for permission and possibly a path, and report that we are starting.
	if(delegate)
	{
		if(![delegate unarchiver:self shouldExtractEntryWithDictionary:dict suggestedPath:&path])
		{
			[pool release];
			return XADErrorNone;
		}
		if ([delegate respondsToSelector:@selector(unarchiver:willExtractEntryWithDictionary:to:)]) {
			[delegate unarchiver:self willExtractEntryWithDictionary:dict to:path];
		}
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
			if(error!=XADErrorSubArchive) goto end;
		}
	}

	// Extract normally.
	if(isres)
	{
		switch(forkstyle)
		{
			case XADForkStyleIgnored:
			break;

			case XADForkStyleMacOSX:
				if(!isdir)
				error=[XADPlatform extractResourceForkEntryWithDictionary:dict unarchiver:self toPath:path];
			break;

			case XADForkStyleHiddenAppleDouble:
			case XADForkStyleVisibleAppleDouble:
				error=[self _extractResourceForkEntryWithDictionary:dict asAppleDoubleFile:path];
			break;

			case XADForkStyleHFVExplorerAppleDouble:
				// We need to make sure there is an empty file for the data fork in all
				// cases, so just try to recover the original filename and create an empty
				// file there in case one doesn't exist, and this isn't a directory.
				// Kludge in the same file attributes as the resource fork. If there is
				// an actual data fork later, it will overwrite this file. There special-case
				// code to avoid collision warnings.
				if(![[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:NULL] && !isdir)
				{
					NSString *dirpart=[path stringByDeletingLastPathComponent];
					NSString *namepart=[path lastPathComponent];
					if([namepart hasPrefix:@"%"])
					{
						NSString *originalname=[namepart substringFromIndex:1];
						NSString *datapath=[dirpart stringByAppendingPathComponent:originalname];
						[[NSData data] writeToFile:datapath atomically:NO];
						[self _updateFileAttributesAtPath:datapath forEntryWithDictionary:dict deferDirectories:!force];
					}
				}
				error=[self _extractResourceForkEntryWithDictionary:dict asAppleDoubleFile:path];
			break;

			default:
				// TODO: better error
				error=XADErrorBadParameters;
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

	if(!error)
	{
		error=[self _updateFileAttributesAtPath:path forEntryWithDictionary:dict deferDirectories:!force];
	}

	// Report success or failure
	end:
	if([delegate respondsToSelector:@selector(unarchiver:didExtractEntryWithDictionary:to:error:)])
	{
		[delegate unarchiver:self didExtractEntryWithDictionary:dict to:path error:error];
	}

	[pool release];

	return error;
}

// FIXME: Improve extractEntryWithDictionary:as:forceDirectories:error: with an NSError value.
-(BOOL)extractEntryWithDictionary:(NSDictionary *)dict as:(NSString *)path forceDirectories:(BOOL)force error:(NSError**)outErr
{
	NSError *tmpErr = nil;
	BOOL okay;
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	NSNumber *dirnum=[dict objectForKey:XADIsDirectoryKey];
	NSNumber *linknum=[dict objectForKey:XADIsLinkKey];
	NSNumber *resnum=[dict objectForKey:XADIsResourceForkKey];
	NSNumber *archivenum=[dict objectForKey:XADIsArchiveKey];
	BOOL isdir=dirnum&&dirnum.boolValue;
	BOOL islink=linknum&&linknum.boolValue;
	BOOL isres=resnum&&resnum.boolValue;
	BOOL isarchive=archivenum&&archivenum.boolValue;

	// If we were not given a path, pick one ourselves.
	if(!path)
	{
		XADPath *name=[dict objectForKey:XADFileNameKey];
		NSString *namestring=name.sanitizedPathString;

		if(destination) path=[destination stringByAppendingPathComponent:namestring];
		else path=namestring;

		// Adjust path for resource forks.
		path=[self adjustPathString:path forEntryWithDictionary:dict];
	}

	// Ask for permission and possibly a path, and report that we are starting.
	if(delegate)
	{
		if(![delegate unarchiver:self shouldExtractEntryWithDictionary:dict suggestedPath:&path])
		{
			return YES;
		}
		if ([delegate respondsToSelector:@selector(unarchiver:willExtractEntryWithDictionary:to:)]) {
			[delegate unarchiver:self willExtractEntryWithDictionary:dict to:path];
		}
	}

	XADError error=0;
	
	okay=[self _ensureDirectoryExists:path.stringByDeletingLastPathComponent error:&tmpErr];
	[tmpErr retain];
	if(!okay) goto end;

	// Attempt to extract embedded archives if requested.
	if(isarchive&&delegate)
	{
		NSString *unarchiverpath=path.stringByDeletingLastPathComponent;

		if([delegate unarchiver:self shouldExtractArchiveEntryWithDictionary:dict to:unarchiverpath])
		{
			okay=[self _extractArchiveEntryWithDictionary:dict to:unarchiverpath name:path.lastPathComponent error:&tmpErr];
			[tmpErr retain];
			// If extraction was attempted, and succeeded for failed, skip everything else.
			// Otherwise, if the archive couldn't be opened, fall through and extract normally.
			if(!okay && ([tmpErr.domain isEqualToString:XADErrorDomain] && tmpErr.code != XADErrorSubArchive)) goto end;
		}
	}

	// Extract normally.
	if(isres)
	{
		switch(forkstyle)
		{
			case XADForkStyleIgnored:
			break;

			case XADForkStyleMacOSX:
				if(!isdir) {
					error=[XADPlatform extractResourceForkEntryWithDictionary:dict unarchiver:self toPath:path];
					if (error == XADErrorNone) {
						okay = YES;
						tmpErr = nil;
					} else {
						okay = NO;
						tmpErr = [[NSError alloc] initWithDomain:XADErrorDomain code:error userInfo:nil];
					}
				}
			break;

			case XADForkStyleHiddenAppleDouble:
			case XADForkStyleVisibleAppleDouble:
			{
				error=[self _extractResourceForkEntryWithDictionary:dict asAppleDoubleFile:path];
				if (error == XADErrorNone) {
					okay = YES;
					tmpErr = nil;
				} else {
					okay = NO;
					tmpErr = [[NSError alloc] initWithDomain:XADErrorDomain code:error userInfo:nil];
				}
			}
			break;

			case XADForkStyleHFVExplorerAppleDouble:
				// We need to make sure there is an empty file for the data fork in all
				// cases, so just try to recover the original filename and create an empty
				// file there in case one doesn't exist, and this isn't a directory.
				// Kludge in the same file attributes as the resource fork. If there is
				// an actual data fork later, it will overwrite this file. There special-case
				// code to avoid collision warnings.
				if(![[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:NULL] && !isdir)
				{
					NSString *dirpart=path.stringByDeletingLastPathComponent;
					NSString *namepart=path.lastPathComponent;
					if([namepart hasPrefix:@"%"])
					{
						NSString *originalname=[namepart substringFromIndex:1];
						NSString *datapath=[dirpart stringByAppendingPathComponent:originalname];
						[[NSData data] writeToFile:datapath atomically:NO];
						[self _updateFileAttributesAtPath:datapath forEntryWithDictionary:dict deferDirectories:!force];
					}
				}
				error=[self _extractResourceForkEntryWithDictionary:dict asAppleDoubleFile:path];
				if (error == XADErrorNone) {
					okay = YES;
					tmpErr = nil;
				} else {
					okay = NO;
					tmpErr = [[NSError alloc] initWithDomain:XADErrorDomain code:error userInfo:nil];
				}
			break;

			default:
				// TODO: better error
				error=XADErrorBadParameters;
				okay = NO;
				tmpErr = [[NSError alloc] initWithDomain:XADErrorDomain code:XADErrorBadParameters userInfo:nil];

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

	if(!error)
	{
		error=[self _updateFileAttributesAtPath:path forEntryWithDictionary:dict deferDirectories:!force];
	}

	if (error == XADErrorNone) {
		okay = YES;
		tmpErr = nil;
	} else {
		okay = NO;
		tmpErr = [[NSError alloc] initWithDomain:XADErrorDomain code:error userInfo:nil];
	}

	// Report success or failure
	end:
	if([delegate respondsToSelector:@selector(unarchiver:didExtractEntryWithDictionary:to:error:)])
	{
		[delegate unarchiver:self didExtractEntryWithDictionary:dict to:path nserror:okay ? nil : tmpErr];
	}
	[pool release];
	
	if (outErr && tmpErr) {
		*outErr = [tmpErr autorelease];
	} else if (tmpErr) {
		[tmpErr release];
	}

	return okay;
}

static NSComparisonResult SortDirectoriesByDepthAndResource(id entry1,id entry2,void *context)
{
	NSDictionary *dict1=[entry1 objectAtIndex:1];
	NSDictionary *dict2=[entry2 objectAtIndex:1];

	XADPath *path1=[dict1 objectForKey:XADFileNameKey];
	XADPath *path2=[dict2 objectForKey:XADFileNameKey];
	NSInteger depth1=[path1 depth];
	NSInteger depth2=[path2 depth];
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
	XADError error;

	error=[self _fixDeferredLinks];
	if(error) return error;

	error=[self _fixDeferredDirectories];
	if(error) return error;

	return XADErrorNone;
}

-(XADError)_fixDeferredLinks
{
	for(NSArray *entry in deferredlinks)
	{
		NSString *path=[entry objectAtIndex:0];
		NSString *linkdest=[entry objectAtIndex:1];
		NSDictionary *dict=[entry objectAtIndex:2];

		XADError error;

		error=[XADPlatform createLinkAtPath:path withDestinationPath:linkdest];
		if(error) return error;

		error=[self _updateFileAttributesAtPath:path forEntryWithDictionary:dict deferDirectories:NO];
		if(error) return error;
	}

	[deferredlinks removeAllObjects];

	return XADErrorNone;
}

-(XADError)_fixDeferredDirectories
{
	[deferreddirectories sortUsingFunction:SortDirectoriesByDepthAndResource context:NULL];

	for(NSArray *entry in deferreddirectories)
	{
		NSString *path=[entry objectAtIndex:0];
		NSDictionary *dict=[entry objectAtIndex:1];

		XADError error=[self _updateFileAttributesAtPath:path forEntryWithDictionary:dict deferDirectories:NO];
		if(error) return error;
	}

	[deferreddirectories removeAllObjects];

	return XADErrorNone;
}



-(XADUnarchiver *)unarchiverForEntryWithDictionary:(NSDictionary *)dict
wantChecksum:(BOOL)checksum nserror:(NSError **)errorptr
{
	return [self unarchiverForEntryWithDictionary:dict resourceForkDictionary:nil
	wantChecksum:checksum nserror:errorptr];
}

-(XADUnarchiver *)unarchiverForEntryWithDictionary:(NSDictionary *)dict
wantChecksum:(BOOL)checksum error:(XADError *)errorptr
{
	return [self unarchiverForEntryWithDictionary:dict resourceForkDictionary:nil
	wantChecksum:checksum error:errorptr];
}

-(XADUnarchiver *)unarchiverForEntryWithDictionary:(NSDictionary *)dict
resourceForkDictionary:(NSDictionary *)forkdict wantChecksum:(BOOL)checksum error:(XADError *)errorptr
{
	XADArchiveParser *subparser=[XADArchiveParser
	archiveParserForEntryWithDictionary:dict
	resourceForkDictionary:forkdict
	archiveParser:parser wantChecksum:checksum error:errorptr];
	if(!subparser) return nil;

	XADUnarchiver *subunarchiver=[XADUnarchiver unarchiverForArchiveParser:subparser];
	[subunarchiver setDelegate:delegate];
	[subunarchiver setDestination:destination];
	[subunarchiver setMacResourceForkStyle:forkstyle];
	[subunarchiver setPreservesPermissions:preservepermissions];
	[subunarchiver setUpdateInterval:updateinterval];

	return subunarchiver;
}


-(XADUnarchiver *)unarchiverForEntryWithDictionary:(NSDictionary *)dict
							resourceForkDictionary:(NSDictionary *)forkdict wantChecksum:(BOOL)checksum nserror:(NSError **)errorptr
{
	XADArchiveParser *subparser=[XADArchiveParser
								 archiveParserForEntryWithDictionary:dict
								 resourceForkDictionary:forkdict
								 archiveParser:parser wantChecksum:checksum nserror:errorptr];
	if(!subparser) return nil;
	
	XADUnarchiver *subunarchiver=[XADUnarchiver unarchiverForArchiveParser:subparser];
	subunarchiver.delegate = delegate;
	subunarchiver.destination = destination;
	subunarchiver.macResourceForkStyle = forkstyle;
	subunarchiver.preservesPermissions = preservepermissions;
	subunarchiver.updateInterval = updateinterval;
	
	return subunarchiver;
}



-(XADError)_extractFileEntryWithDictionary:(NSDictionary *)dict as:(NSString *)destpath
{
	CSHandle *fh;
	@try { fh=[CSFileHandle fileHandleForWritingAtPath:destpath]; }
	@catch(id e) { return XADErrorOpenFile; }

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
    // linkdest can be empty or nil if the link points to a deleted file.
    // linkdest must have a value to be used in the fileSystemRepresentation, otherwise it will crash.
	if(!linkdest || linkdest.length == 0) return XADErrorNone; // Handle nil returns as a request to skip.

	// Check if the link destination is an absolute path, or if it contains
	// any .. path components.
	if([linkdest hasPrefix:@"/"] || [linkdest isEqual:@".."] ||
	[linkdest hasPrefix:@"../"] || [linkdest hasSuffix:@"/.."] ||
	[linkdest rangeOfString:@"/../"].location!=NSNotFound)
	{
		// If so, consider it unsafe, and create a placeholder file instead,
		// and create the real link only in finishExtractions.
		CSHandle *fh;
		@try { fh=[CSFileHandle fileHandleForWritingAtPath:destpath]; }
		@catch(id e)
		{
			unlink([destpath fileSystemRepresentation]);
			@try { fh=[CSFileHandle fileHandleForWritingAtPath:destpath]; }
			@catch(id e) { return XADErrorOpenFile; }
		}
		[fh close];

		[deferredlinks addObject:[NSArray arrayWithObjects:destpath,linkdest,dict,nil]];
		return XADErrorNone;
	}
	else
	{
		return [XADPlatform createLinkAtPath:destpath withDestinationPath:linkdest];
	}
}

-(XADError)_extractArchiveEntryWithDictionary:(NSDictionary *)dict to:(NSString *)destpath name:(NSString *)filename
{
	XADError error;
	XADUnarchiver *subunarchiver=[self unarchiverForEntryWithDictionary:dict
	wantChecksum:YES error:&error];
	if(!subunarchiver)
	{
		if(error) return error;
		else return XADErrorSubArchive;
	}

	[subunarchiver setDestination:destpath];

	[delegate unarchiver:self willExtractArchiveEntryWithDictionary:dict
	withUnarchiver:subunarchiver to:destpath];

	error=[subunarchiver parseAndUnarchive];

	[delegate unarchiver:self didExtractArchiveEntryWithDictionary:dict
	withUnarchiver:subunarchiver to:destpath error:error];

	return error;
}

-(BOOL)_extractArchiveEntryWithDictionary:(NSDictionary *)dict to:(NSString *)destpath name:(NSString *)filename error:(NSError**)outError
{
	XADUnarchiver *subunarchiver=[self unarchiverForEntryWithDictionary:dict wantChecksum:YES nserror:outError];
	if(!subunarchiver)
	{
		if (outError) {
			if (*outError) {
				//Do nothing
			} else {
				*outError = [NSError errorWithDomain:XADErrorDomain code:XADErrorSubArchive userInfo:nil];
			}
		}
		return NO;
	}

	subunarchiver.destination = destpath;

	[delegate unarchiver:self willExtractArchiveEntryWithDictionary:dict
	withUnarchiver:subunarchiver to:destpath];

	NSError *tmpErr;
	BOOL success=[subunarchiver parseAndUnarchiveWithError:&tmpErr];

	[delegate unarchiver:self didExtractArchiveEntryWithDictionary:dict
	withUnarchiver:subunarchiver to:destpath nserror:tmpErr];
	if (tmpErr && outError) {
		*outError = tmpErr;
	}

	return success;
}

-(XADError)_extractResourceForkEntryWithDictionary:(NSDictionary *)dict asAppleDoubleFile:(NSString *)destpath
{
	CSHandle *fh;
	@try { fh=[CSFileHandle fileHandleForWritingAtPath:destpath]; }
	@catch(id e) { return XADErrorOpenFile; }

	off_t ressize=0;
	NSNumber *sizenum=[dict objectForKey:XADFileSizeKey];
	if(sizenum) ressize=[sizenum longLongValue];

	NSDictionary *extattrs=[parser extendedAttributesForDictionary:dict];

	@try
	{
		// TODO: Should this function handle exceptions itself?
		[XADAppleDouble writeAppleDoubleHeaderToHandle:fh resourceForkSize:(int)ressize
		extendedAttributes:extattrs];
	}
	@catch(id e) { return [XADException parseException:e]; }

	// Write resource fork.
	XADError error=XADErrorNone;
	if(ressize) error=[self runExtractorWithDictionary:dict outputHandle:fh];

	[fh close];

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
			return XADErrorNone;
		}
	}

	return [XADPlatform updateFileAttributesAtPath:path forEntryWithDictionary:dict
	parser:parser preservePermissions:preservepermissions];
}

-(BOOL)_ensureDirectoryExists:(NSString *)path error:(NSError**)outError
{
	if(path.length==0) return YES;

	NSFileManager *manager=[NSFileManager defaultManager];

	BOOL isdir;
	if([manager fileExistsAtPath:path isDirectory:&isdir])
	{
		if(isdir) return YES;

		if(!delegate || ![delegate respondsToSelector:@selector(unarchiver:shouldDeleteFileAndCreateDirectory:)]) {
			if (outError) {
				*outError = [NSError errorWithDomain:XADErrorDomain code:XADErrorMakeDirectory userInfo:nil];
			}
			return NO;
		}
		if(![delegate unarchiver:self shouldDeleteFileAndCreateDirectory:path]) {
			if (outError) {
				*outError = [NSError errorWithDomain:XADErrorDomain code:XADErrorMakeDirectory userInfo:nil];
			}
			return NO;
		}
		if(![XADPlatform removeItemAtPath:path]) {
			if (outError) {
				*outError = [NSError errorWithDomain:XADErrorDomain code:XADErrorMakeDirectory userInfo:nil];
			}
			return NO;
		}
	}
	else
	{
		BOOL success=[self _ensureDirectoryExists:path.stringByDeletingLastPathComponent error:outError];
		if(!success) return NO;

		if(delegate && [delegate respondsToSelector:@selector(unarchiver:shouldCreateDirectory:)]) {
			if(![delegate unarchiver:self shouldCreateDirectory:path]) {
				if (outError) {
					*outError = [NSError errorWithDomain:XADErrorDomain code:XADErrorMakeDirectory userInfo:nil];
				}
				return NO;
			}
		}
	}

	return [manager createDirectoryAtPath:path
			  withIntermediateDirectories:NO attributes:nil error:outError];
}

-(XADError)_ensureDirectoryExists:(NSString *)path
{
	if([path length]==0) return XADErrorNone;

	NSFileManager *manager=[NSFileManager defaultManager];

	BOOL isdir;
	if([manager fileExistsAtPath:path isDirectory:&isdir])
	{
		if(isdir) return XADErrorNone;

		if(!delegate || ![delegate respondsToSelector:@selector(unarchiver:shouldDeleteFileAndCreateDirectory:)]) return XADErrorMakeDirectory;
		if(![delegate unarchiver:self shouldDeleteFileAndCreateDirectory:path]) return XADErrorMakeDirectory;
		if(![XADPlatform removeItemAtPath:path]) return XADErrorMakeDirectory;
	}
	else
	{
		XADError error=[self _ensureDirectoryExists:[path stringByDeletingLastPathComponent]];
		if(error) return error;

		if(delegate)
		{
			if(![delegate unarchiver:self shouldCreateDirectory:path]) return XADErrorMakeDirectory;
		}
	}

	#if MAC_OS_X_VERSION_MIN_REQUIRED>=1050 || __IPHONE_OS_VERSION_MIN_REQUIRED>__IPHONE_2_0
	if([manager createDirectoryAtPath:path
          withIntermediateDirectories:NO attributes:nil error:NULL]) {
		if ([delegate respondsToSelector:@selector(unarchiver:didCreateDirectory:)]) {
            [delegate unarchiver:self didCreateDirectory:path];
        }
		return XADErrorNone;
    }
	#else
    if([manager createDirectoryAtPath:path attributes:nil]) {
        if ([delegate respondsToSelector:@selector(unarchiver:didCreateDirectory:)]) {
            [delegate unarchiver:self didCreateDirectory:path];
        }
        return XADErrorNone;
    }
	#endif
	else return XADErrorMakeDirectory;
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
	@catch(id e) { return XADErrorOutput; }
	return XADErrorNone;
}

-(XADError)runExtractorWithDictionary:(NSDictionary *)dict
outputTarget:(id)target selector:(SEL)selector argument:(id)argument
{
	XADError (*outputfunc)(id,SEL,id,uint8_t *,int);
	outputfunc=(void *)[target methodForSelector:selector];

	uint8_t *buf=NULL;

	@try
	{
		// Send a progress report to show that we are starting.
		if ([delegate respondsToSelector:@selector(unarchiver:extractionProgressForEntryWithDictionary:fileFraction:estimatedTotalFraction:)]) {
			[delegate unarchiver:self extractionProgressForEntryWithDictionary:dict
			fileFraction:0 estimatedTotalFraction:[[parser handle] estimatedProgress]];
		}

		// Try to find the size of this entry.
		NSNumber *sizenum=[dict objectForKey:XADFileSizeKey];
		off_t size=0;
		if(sizenum)
		{
			size=[sizenum longLongValue];

			// If this file is empty, don't bother reading anything, just
			// call the output function once with 0 bytes and return.
			if(size==0) return outputfunc(target,selector,argument,(uint8_t *)"",0);
		}

		// Create handle and start unpacking.
		CSHandle *srchandle=[parser handleForEntryWithDictionary:dict wantChecksum:YES];
		if(!srchandle) return XADErrorNotSupported;

		off_t done=0;
		double updatetime=0;

		const int bufsize=0x40000;
		buf=malloc(bufsize);
		if(!buf) [XADException raiseOutOfMemoryException];

		for(;;)
		{
			if([self _shouldStop]) {
				free(buf);
				return XADErrorBreak;
			}

			// Read some data, and send it to the output function.
			// Stop if no more data was available.
			int actual=[srchandle readAtMost:bufsize toBuffer:buf];
			if(actual)
			{
				XADError error=outputfunc(target,selector,argument,buf,actual);
				if(error) return error;
			}
			else break;

			done+=actual;

			// Occasionally, send a progress message.
			double currtime=[XADPlatform currentTimeInSeconds];
			if(currtime-updatetime>updateinterval)
			{
				updatetime=currtime;

				double progress;
				if(sizenum) progress=(double)done/(double)size;
				else progress=[srchandle estimatedProgress];

				if ([delegate respondsToSelector:@selector(unarchiver:extractionProgressForEntryWithDictionary:fileFraction:estimatedTotalFraction:)]) {
					[delegate unarchiver:self extractionProgressForEntryWithDictionary:dict
					fileFraction:progress estimatedTotalFraction:[[parser handle] estimatedProgress]];
				}
			}
		}

		// Check if the file has already been marked as corrupt, and
		// give up without testing checksum if so.
		NSNumber *iscorrupt=[dict objectForKey:XADIsCorruptedKey];
		if(iscorrupt&&[iscorrupt boolValue]) return XADErrorDecrunch;

		// If the file has a checksum, check it. Otherwise, if it has a
		// size, check that the size ended up correct.
		if([srchandle hasChecksum])
		{
			if(![srchandle isChecksumCorrect]) return XADErrorChecksum;
		}
		else
		{
			if(sizenum&&done!=size) return XADErrorDecrunch; // kind of hacky
		}

		// Send a final progress report.
		if ([delegate respondsToSelector:@selector(unarchiver:extractionProgressForEntryWithDictionary:fileFraction:estimatedTotalFraction:)]) {
			[delegate unarchiver:self extractionProgressForEntryWithDictionary:dict
			fileFraction:1 estimatedTotalFraction:parser.handle.estimatedProgress];
		}
	}
	@catch(id e)
	{
		return [XADException parseException:e];
	}

	free(buf);

	return XADErrorNone;
}

-(BOOL)runExtractorWithDictionary:(NSDictionary *)dict outputHandle:(CSHandle *)handle error:(NSError **)outError
{
	return [self runExtractorWithDictionary:dict outputTarget:self
	selector:@selector(_outputToHandle:bytes:length:) argument:handle error:outError];
}

-(BOOL)runExtractorWithDictionary:(NSDictionary *)dict
outputTarget:(id)target selector:(SEL)selector argument:(id)argument error:(NSError**)outError;
{
	XADError (*outputfunc)(id,SEL,id,uint8_t *,int);
	outputfunc=(void *)[target methodForSelector:selector];

	uint8_t *buf=NULL;

	@try
	{
		// Send a progress report to show that we are starting.
		if ([delegate respondsToSelector:@selector(unarchiver:extractionProgressForEntryWithDictionary:fileFraction:estimatedTotalFraction:)]) {
			[delegate unarchiver:self extractionProgressForEntryWithDictionary:dict
			fileFraction:0 estimatedTotalFraction:parser.handle.estimatedProgress];
		}

		// Try to find the size of this entry.
		NSNumber *sizenum=[dict objectForKey:XADFileSizeKey];
		off_t size=0;
		if(sizenum != nil)
		{
			size=sizenum.longLongValue;

			// If this file is empty, don't bother reading anything, just
			// call the output function once with 0 bytes and return.
			if(size==0) {
				XADError error = outputfunc(target,selector,argument,(uint8_t *)"",0);
				if (error == XADErrorNone) {
					return YES;
				} else if(outError) {
					*outError = [NSError errorWithDomain:XADErrorDomain code:error userInfo:nil];
				}
				return NO;
			}
		}

		// Create handle and start unpacking.
		CSHandle *srchandle=[parser handleForEntryWithDictionary:dict wantChecksum:YES nserror:outError];
		if(!srchandle) return NO;

		off_t done=0;
		double updatetime=0;

		const int bufsize=0x40000;
		buf=malloc(bufsize);
		if(!buf) [XADException raiseOutOfMemoryException];

		for(;;)
		{
			if(self._shouldStop) {
				free(buf);
				if (outError) {
					*outError = [NSError errorWithDomain:XADErrorDomain code:XADErrorBreak userInfo:nil];
				}
				return NO;
			}

			// Read some data, and send it to the output function.
			// Stop if no more data was available.
			int actual=[srchandle readAtMost:bufsize toBuffer:buf];
			if(actual)
			{
				XADError error=outputfunc(target,selector,argument,buf,actual);
				if(error) {
					if (outError) {
						*outError = [NSError errorWithDomain:XADErrorDomain code:error userInfo:nil];
					}
					return NO;
				}
			}
			else break;

			done+=actual;

			// Occasionally, send a progress message.
			double currtime=[XADPlatform currentTimeInSeconds];
			if(currtime-updatetime>updateinterval)
			{
				updatetime=currtime;

				double progress;
				if(sizenum != nil) progress=(double)done/(double)size;
				else progress=srchandle.estimatedProgress;

				if ([delegate respondsToSelector:@selector(unarchiver:extractionProgressForEntryWithDictionary:fileFraction:estimatedTotalFraction:)]) {
					[delegate unarchiver:self extractionProgressForEntryWithDictionary:dict
					fileFraction:progress estimatedTotalFraction:parser.handle.estimatedProgress];
				}
			}
		}

		// Check if the file has already been marked as corrupt, and
		// give up without testing checksum if so.
		NSNumber *iscorrupt=[dict objectForKey:XADIsCorruptedKey];
		if(iscorrupt&&iscorrupt.boolValue) {
			if (outError) {
				*outError = [NSError errorWithDomain:XADErrorDomain code:XADErrorDecrunch userInfo:nil];
			}
			return NO;
		}

		// If the file has a checksum, check it. Otherwise, if it has a
		// size, check that the size ended up correct.
		if(srchandle.hasChecksum)
		{
			if(![srchandle isChecksumCorrect]) {
				if (outError) {
					*outError = [NSError errorWithDomain:XADErrorDomain code:XADErrorChecksum userInfo:nil];
				}
				return NO;
			}
		}
		else
		{
			if(sizenum&&done!=size) {
				if (outError) {
					*outError = [NSError errorWithDomain:XADErrorDomain code:XADErrorDecrunch userInfo:nil]; // kind of hacky
				}
				return NO;
			}
		}

		// Send a final progress report.
		if ([delegate respondsToSelector:@selector(unarchiver:extractionProgressForEntryWithDictionary:fileFraction:estimatedTotalFraction:)]) {
			[delegate unarchiver:self extractionProgressForEntryWithDictionary:dict
			fileFraction:1 estimatedTotalFraction:parser.handle.estimatedProgress];
		}
	}
	@catch(id e)
	{
		if (outError) {
			*outError = [XADException parseExceptionReturningNSError:e];
		}
		return NO;
	}

	free(buf);

	return YES;
}

-(NSString *)adjustPathString:(NSString *)path forEntryWithDictionary:(NSDictionary *)dict
{
	// If we are unpacking a resource fork, we may need to modify the path.
	NSNumber *resnum=[dict objectForKey:XADIsResourceForkKey];
	if(resnum&&[resnum boolValue])
	{
		switch(forkstyle)
		{
			case XADForkStyleHiddenAppleDouble:
				// TODO: is this path generation correct?
				return [[path stringByDeletingLastPathComponent] stringByAppendingPathComponent:
				[@"._" stringByAppendingString:[path lastPathComponent]]];
			break;

			case XADForkStyleVisibleAppleDouble:
				return [path stringByAppendingPathExtension:@"rsrc"];
			break;

			case XADForkStyleHFVExplorerAppleDouble:
				// TODO: is this path generation correct?
				// FIXME: this is not correct: HFVExplorer requires non-ascii characters to be percent-encoded.
				return [[path stringByDeletingLastPathComponent] stringByAppendingPathComponent:
				[@"%" stringByAppendingString:[path lastPathComponent]]];
			break;
		}
	}
	return path;
}

-(BOOL)_shouldStop
{
	if(!delegate) return NO;
	if(shouldstop) return YES;

	if ([delegate respondsToSelector:@selector(extractionShouldStopForUnarchiver:)]) {
		shouldstop=[delegate extractionShouldStopForUnarchiver:self];
	}
	return shouldstop;
}

-(void)setPreserevesPermissions:(BOOL)preserve
{
	self.preservesPermissions = preserve;
}

@end


//TODO: remove all of these: migrate needed code to XADUnarchiver.
@implementation NSObject (XADUnarchiverDelegate)

-(NSString *)unarchiver:(XADUnarchiver *)unarchiver pathForExtractingEntryWithDictionary:(NSDictionary *)dict { return nil; }

-(BOOL)unarchiver:(XADUnarchiver *)unarchiver shouldExtractEntryWithDictionary:(NSDictionary *)dict suggestedPath:(NSString **)pathptr
{
	// Kludge to handle old-style interface.
	if([self respondsToSelector:@selector(unarchiver:shouldExtractEntryWithDictionary:to:)])
	{
		NSString *path=[self unarchiver:unarchiver pathForExtractingEntryWithDictionary:dict];
		if(path) *pathptr=path;
		#pragma clang diagnostic push
		#pragma clang diagnostic ignored "-Wdeprecated"
		return [(NSObject<XADUnarchiverDelegate>*)self unarchiver:unarchiver shouldExtractEntryWithDictionary:dict to:*pathptr];
		#pragma clang diagnostic pop
	}
	else return YES;
}

-(BOOL)unarchiver:(XADUnarchiver *)unarchiver shouldExtractArchiveEntryWithDictionary:(NSDictionary *)dict to:(NSString *)path { return NO; }
-(void)unarchiver:(XADUnarchiver *)unarchiver willExtractArchiveEntryWithDictionary:(NSDictionary *)dict withUnarchiver:(XADUnarchiver *)subunarchiver to:(NSString *)path {}
-(void)unarchiver:(XADUnarchiver *)unarchiver didExtractArchiveEntryWithDictionary:(NSDictionary *)dict withUnarchiver:(XADUnarchiver *)subunarchiver to:(NSString *)path error:(XADError)error
{
	if ([self respondsToSelector:@selector(unarchiver:didExtractArchiveEntryWithDictionary:withUnarchiver:to:nserror:)]) {
		[(NSObject<XADUnarchiverDelegate>*)self unarchiver:unarchiver didExtractArchiveEntryWithDictionary:dict withUnarchiver:subunarchiver to:path nserror:error == XADErrorNone ? nil : [NSError errorWithDomain:XADErrorDomain code:error userInfo:nil]];
	}
}

-(void)unarchiver:(XADUnarchiver *)unarchiver didExtractEntryWithDictionary:(NSDictionary *)dict to:(NSString *)path error:(XADError)error
{
	if ([self respondsToSelector:@selector(unarchiver:didExtractEntryWithDictionary:to:nserror:)]) {
		[(NSObject<XADUnarchiverDelegate>*)self unarchiver:unarchiver didExtractEntryWithDictionary:dict to:path nserror:error == XADErrorNone ? nil : [NSError errorWithDomain:XADErrorDomain code:error userInfo:nil]];
	}
}

-(NSString *)unarchiver:(XADUnarchiver *)unarchiver destinationForLink:(XADString *)link from:(NSString *)path
{
	// Kludge to handle old-style interface.
	if([self respondsToSelector:@selector(unarchiver:linkDestinationForEntryWithDictionary:from:)])
	{
		#pragma clang diagnostic push
		#pragma clang diagnostic ignored "-Wdeprecated"
		return [(NSObject<XADUnarchiverDelegate>*)self unarchiver:unarchiver linkDestinationForEntryWithDictionary:
		[NSMutableDictionary dictionaryWithObjectsAndKeys:
			link,XADLinkDestinationKey,
			[NSNumber numberWithBool:YES],XADIsLinkKey,
		nil] from:path];
		#pragma clang diagnostic pop
	}
	else return [link string];
}


@end

