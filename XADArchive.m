/*#include <unistd.h>
#include <sys/stat.h>
#include <dirent.h>
#include <fcntl.h>*/

#define XAD_NO_DEPRECATED

#import "XADArchive.h"
#import "XADRegex.h"

#import <UniversalDetector/UniversalDetector.h>







@implementation XADArchive

+(XADArchive *)archiveForFile:(NSString *)filename
{
	return [[[XADArchive alloc] initWithFile:filename] autorelease];
}

+(XADArchive *)recursiveArchiveForFile:(NSString *)filename
{
	XADArchive *archive=[self archiveForFile:filename];

	while([archive numberOfEntries]==1)
	{
		XADArchive *subarchive=[[XADArchive alloc] initWithArchive:archive entry:0];
		if(subarchive) archive=[subarchive autorelease];
		else
		{
			[subarchive release];
			break;
		}
	}

	return archive;
}

static int XADVolumeSort(NSString *str1,NSString *str2,void *dummy)
{
	BOOL israr1=[[str1 lowercaseString] hasSuffix:@".rar"];
	BOOL israr2=[[str2 lowercaseString] hasSuffix:@".rar"];

	if(israr1&&!israr2) return NSOrderedAscending;
	else if(!israr1&&israr2) return NSOrderedDescending;
	else return [str1 compare:str2 options:NSCaseInsensitiveSearch|NSNumericSearch];
}

+(NSArray *)volumesForFile:(NSString *)filename
{
	NSString *namepart=[filename lastPathComponent];
	NSString *dirpart=[filename stringByDeletingLastPathComponent];
	NSArray *matches;
	NSString *pattern;

	if(matches=[namepart substringsCapturedByPattern:@"^(.*)\\.part[0-9]+\\.rar$" options:REG_ICASE])
	{
		pattern=[NSString stringWithFormat:@"^%@\\.part[0-9]+\\.rar$",[[matches objectAtIndex:1] escapedPattern]];
	}
	else if(matches=[namepart substringsCapturedByPattern:@"^(.*)\\.(rar|r[0-9]{2}|s[0-9]{2})$" options:REG_ICASE])
	{
		pattern=[NSString stringWithFormat:@"^%@\\.(rar|r[0-9]{2}|s[0-9]{2})$",[[matches objectAtIndex:1] escapedPattern]];
	}
	else if(matches=[namepart substringsCapturedByPattern:@"^(.*)\\.[0-9]+$"])
	{
		pattern=[NSString stringWithFormat:@"^%@\\.[0-9]+$",[[matches objectAtIndex:1] escapedPattern]];
	}
	else return nil;

	XADRegex *regex=[XADRegex regexWithPattern:pattern options:REG_ICASE];
	NSMutableArray *files=[NSMutableArray array];

	DIR *dir=opendir([dirpart fileSystemRepresentation]);

	struct dirent *ent;
	while(ent=readdir(dir))
	{
		NSString *entname=[NSString stringWithUTF8String:ent->d_name];
		if([regex matchesString:entname]) [files addObject:
		[dirpart stringByAppendingPathComponent:entname]];
	}

	if([files count]<=1) return nil;

	return [files sortedArrayUsingFunction:XADVolumeSort context:NULL];
}




-(id)initWithFile:(NSString *)name handle:(CSHandle *)handle
{
	if(self=[super init])
	{
		inputhandle=[handle retain];
		filename=[filename retain];

		volumes=nil;
		delegate=nil;
		password=nil;

		encrypted=NO;
		solid=NO;

		lasterror=XADNoError;
	}
	return self;
}

-(void)dealloc
{
	[inputhandle release];
	[filename release];
	[volumes release];
	[password release];
//	[dittoforks release];
//	[writeperms release];

	[super dealloc];
}


/*-(id)init
{
	if(self=[super init])
	{
		filename=nil;
		volumes=nil;
		memdata=nil;
		parentarchive=nil;
		pipe=nil;

		delegate=nil;
		name_encoding=0;
		password=nil;
		update_interval=0.1;
		update_time=0;

		xmb=NULL;
		archive=NULL;
		progresshook.h_Entry=XADProgressFunc;
		progresshook.h_Data=(void *)self;

		fileinfos=[[NSMutableArray array] retain];
		dittoforks=[[NSMutableDictionary dictionary] retain];
		writeperms=[[NSMutableArray array] retain];

		extractsize=totalsize=0;
		currentry=0;
		immediatedestination=nil;
		immediatefailed=NO;

		detector=nil;
		detected_encoding=NSWindowsCP1252StringEncoding;
		detector_confidence=0;

		lasterror=XADERR_OK;

		if(xmb=xadOpenLibrary(12))
		{
			if(archive=xadAllocObjectA(xmb,XADOBJ_ARCHIVEINFO,NULL))
			{
				return self;
			}
		}
		[self release];
	}
	return nil;
}

-(id)initWithFile:(NSString *)file { return [self initWithFile:file delegate:nil error:NULL]; }

-(id)initWithFile:(NSString *)file error:(XADError *)error { return [self initWithFile:file delegate:nil error:error]; }

-(id)initWithFile:(NSString *)file delegate:(id)del error:(XADError *)error
{
	if(self=[self init])
	{
		volumes=[[XADArchive volumesForFile:file] retain];

		[self setDelegate:del];

		if(volumes)
		{
			filename=[[volumes objectAtIndex:0] retain];

			int n=[volumes count];
			struct xadSplitFile split[n];

			for(int i=0;i<n;i++)
			{
				if(i!=n-1) split[i].xsf_Next=&split[i+1];
				else split[i].xsf_Next=NULL;

				split[i].xsf_Type=XAD_INFILENAME;
				split[i].xsf_Data=(xadPTRINT)[[volumes objectAtIndex:i] fileSystemRepresentation];
				split[i].xsf_Size=0;
			}

			struct TagItem tags[]={
				XAD_INSPLITTED,(xadPTRINT)split,
			TAG_DONE};

			if([self _finishInit:tags error:error]) return self;
		}
		else
		{
			filename=[file retain];

			const char *fsname=[file fileSystemRepresentation];
			struct TagItem tags[]={
				XAD_INFILENAME,(xadPTRINT)fsname,
			TAG_DONE};

			if([self _finishInit:tags error:error]) return self;
		}

		[self release];
	}
	else if(error) *error=XADERR_NOMEMORY;

	return nil;
}

-(id)initWithData:(NSData *)data { return [self initWithData:data error:NULL]; }

-(id)initWithData:(NSData *)data error:(XADError *)error
{
	if(self=[self init])
	{
		memdata=[data retain];

		struct TagItem tags[]={
			XAD_INMEMORY,(xadPTRINT)[data bytes],
			XAD_INSIZE,[data length],
		TAG_DONE};

		if([self _finishInit:tags error:error]) return self;

		[self release];
	}
	else if(error) *error=XADERR_NOMEMORY;

	return nil;
}

-(id)initWithArchive:(XADArchive *)otherarchive entry:(int)n { return [self initWithArchive:otherarchive entry:n error:NULL]; }

-(id)initWithArchive:(XADArchive *)otherarchive entry:(int)n error:(XADError *)error
{
	if(error) *error=XADERR_NOMEMORY;

	if(self=[self init])
	{
		parentarchive=[otherarchive retain];
		filename=[[otherarchive nameOfEntry:n] retain];

		if(pipe=[[XADArchivePipe alloc] initWithArchive:otherarchive entry:n bufferSize:1024*1024])
		{
			struct TagItem tags[]={
				XAD_INHOOK,(xadPTRINT)[pipe inHook],
			TAG_DONE};

			if([self _finishInit:tags error:error]) return self;
		}
		else if(error) *error=XADERR_NOMEMORY;

		[self release];
	}
	else if(error) *error=XADERR_NOMEMORY;

	return nil;
}

-(id)initWithArchive:(XADArchive *)otherarchive entry:(int)n
     immediateExtractionTo:(NSString *)destination error:(XADError *)error
{
	if(self=[self init])
	{
		parentarchive=[otherarchive retain];
		filename=[[otherarchive nameOfEntry:n] retain];
		immediatedestination=destination;

		[self setDelegate:otherarchive];

		if(pipe=[[XADArchivePipe alloc] initWithArchive:otherarchive entry:n bufferSize:1024*1024])
		{
			struct TagItem tags[]={
				XAD_INHOOK,(xadPTRINT)[pipe inHook],
				[otherarchive entryHasSize:n]?TAG_IGNORE:XAD_CLIENT,XADCID_TAR,
			TAG_DONE};

			if([self _finishInit:tags error:error])
			{
				[self fixWritePermissions];
				immediatedestination=nil;
				return self;
			}
		}
		else if(error) *error=XADERR_NOMEMORY;

		[self release];
	}
	else if(error) *error=XADERR_NOMEMORY;

	return nil;
}

-(BOOL)_finishInit:(xadTAGPTR)tags error:(XADError *)error
{
	struct TagItem alltags[]={ XAD_PROGRESSHOOK,(xadUINT32)&progresshook,TAG_MORE,(xadUINT32)tags,TAG_DONE };

	int err=xadGetInfoA(xmb,archive,alltags);
	if(!err&&archive->xai_DiskInfo)
	{
		xadFreeInfo(xmb,archive);
		err=xadGetDiskInfo(xmb,archive,
			XAD_INDISKARCHIVE,alltags,
		TAG_DONE);
	}
	else if(err==XADERR_FILETYPE) err=xadGetDiskInfoA(xmb,archive,tags);

	if(err)
	{
		if(error) *error=err;
		return NO;
	}

	if(![fileinfos count])
	{
		if(error) *error=XADERR_DATAFORMAT;
		return NO;
	}

	if(error) *error=XADERR_OK;

	return YES;
}

-(xadUINT32)_newEntryCallback:(struct xadProgressInfo *)proginfo
{
	struct xadFileInfo *info=proginfo->xpi_FileInfo;

	// Feed filename to the character set detector
	[self _runDetectorOn:info->xfi_FileName];

	// Skip normal resource forks (except lonely ones)
	if((info->xfi_Flags&XADFIF_MACRESOURCE)&&info->xfi_MacFork)
	{
		// Was this file already extracted without attributes?
		int n=[self _entryIndexOfFileInfo:info->xfi_MacFork];
		if(n!=NSNotFound)
		{
			NSDictionary *attrs=[self attributesOfEntry:n withResourceFork:YES];
			if(attrs) [self _changeAllAttributes:attrs atPath:[immediatedestination stringByAppendingPathComponent:[self nameOfEntry:n]] overrideWritePermissions:YES];
		}
		return XADPIF_OK;
	}

	// Resource forks in ditto archives
	if([self _canHaveDittoResourceForks]&&[self _fileInfoIsDittoResourceFork:info])
	{
//		detected_encoding=NSUTF8StringEncoding;
//		detector_confidence=1;

		NSString *dataname=[self _nameOfDataForkForDittoResourceFork:info];
		if(dataname)
		{
			[dittoforks setObject:[NSValue valueWithPointer:info] forKey:dataname];

			// Doing immediate extraction?
			if(immediatedestination)
			{
				// Was this file already extracted without attributes?
				int n=[self _entryIndexOfName:dataname];
				if(n!=NSNotFound)
				{
					NSDictionary *attrs=[self attributesOfEntry:n withResourceFork:YES];
					if(attrs) [self _changeAllAttributes:attrs atPath:[immediatedestination stringByAppendingPathComponent:dataname] overrideWritePermissions:YES];
				}
			}
		}

		return XADPIF_OK;
	}

	int newindex=[fileinfos count];

	// Check if a resource fork for this file was already erroneously added to the list
	if((info->xfi_Flags&XADFIF_MACDATA)&&info->xfi_MacFork)
	{
		int len=strlen(info->xfi_FileName);
		for(int i=newindex-1;i>=0;i--)
		{
			struct xadFileInfo *other=[[fileinfos objectAtIndex:i] pointerValue];
			int otherlen=strlen(other->xfi_FileName);

			if(strncmp(info->xfi_FileName,other->xfi_FileName,len)==0)
			if(otherlen==len||(otherlen==len+5&&strcmp(other->xfi_FileName+len,".rsrc")==0))
			{
				newindex=i;
				[fileinfos replaceObjectAtIndex:newindex withObject:[NSValue valueWithPointer:info]];
				goto skip;
			}
		}
		// Not found, add entry to the list normally
		[fileinfos addObject:[NSValue valueWithPointer:info]];
	}
	else
	{
		// Add entry to the list
		[fileinfos addObject:[NSValue valueWithPointer:info]];
	}
	skip:

	// Extract the file immediately if requested
	if(immediatedestination)
	{
		if(info->xfi_Flags&(XADFIF_EXTRACTONBUILD|XADFIF_DIRECTORY|XADFIF_LINK))
		{
			if(![self extractEntry:newindex to:immediatedestination overrideWritePermissions:YES])
			{
				immediatefailed=YES;
				return 0;
			}
		}
		else lasterror=XADERR_NOTSUPPORTED;
	}

	return XADPIF_OK;
}
*/


-(NSString *)filename { return filename; }

-(NSArray *)allFilenames
{
	if(volumes) return volumes;
	else return [NSArray arrayWithObject:filename];
}

-(BOOL)isEncrypted { return encrypted; }

-(BOOL)isSolid { return solid; }

-(BOOL)isCorrupted { return NO; } // TODO

-(int)numberOfEntries { return [entries count]; }

-(NSDictionary *)propertiesForEntry:(int)n
{
	return [entries objectAtIndex:n];
}

-(BOOL)immediateExtractionFailed { return NO; } // TODO

-(NSString *)commonTopDirectory
{
	NSString *firstname=[self nameOfEntry:0];
	NSRange slash=[firstname rangeOfString:@"/"];

	NSString *directory;
	if(slash.location!=NSNotFound) directory=[firstname substringToIndex:slash.location];
	else if([self entryIsDirectory:0]) directory=firstname;
	else return nil;

	NSString *dirprefix=[directory stringByAppendingString:@"/"];

	int numentries=[self numberOfEntries];
	for(int i=1;i<numentries;i++)
	if(![[self nameOfEntry:i] hasPrefix:dirprefix]) return nil;

	return directory;
}



-(void)setDelegate:(id)newdelegate { delegate=newdelegate; }

-(id)delegate { return delegate; }



-(NSString *)password { return password; }

-(void)setPassword:(NSString *)newpassword
{
	[password autorelease];
	password=[newpassword retain];
}



-(NSStringEncoding)nameEncoding { return [stringsource encoding]; }

-(void)setNameEncoding:(NSStringEncoding)encoding { [stringsource setFixedEncoding:encoding]; }




-(XADError)lastError { return lasterror; }

-(void)clearLastError { lasterror=XADNoError; }

-(NSString *)describeLastError { return [self describeError:lasterror]; }

-(NSString *)describeError:(XADError)error
{
	switch(error)
	{
		case XADNoError:			return nil;
		case XADUnknownError:		return @"Unknown error";
		case XADInputError:			return @"Input data buffers border exceeded";
		case XADOutputError:		return @"Output data buffers border exceeded";
		case XADBadParametersError:	return @"Function called with illegal parameters";
		case XADOutOfMemoryError:	return @"Not enough memory available";
		case XADIllegalDataError:	return @"Data is corrupted";
		case XADNotSupportedError:	return @"Command is not supported";
		case XADResourceError:		return @"Required resource missing";
		case XADDecrunchError:		return @"Error on decrunching";
		case XADFiletypeError:		return @"Unknown file type";
		case XADOpenFileError:		return @"Opening file failed";
		case XADSkipError:			return @"File, disk has been skipped";
		case XADBreakError:			return @"User break in progress hook";
		case XADFileExistsError:	return @"File already exists";
		case XADPasswordError:		return @"Missing or wrong password";
		case XADMakeDirectoryError:	return @"Could not create directory";
		case XADChecksumError:		return @"Wrong checksum";
		case XADVerifyError:		return @"Verify failed (disk hook)";
		case XADGeometryError:		return @"Wrong drive geometry";
		case XADDataFormatError:	return @"Unknown data format";
		case XADEmptyError:			return @"Source contains no files";
		case XADFileSystemError:	return @"Unknown filesystem";
		case XADFileDirectoryError:	return @"Name of file exists as directory";
		case XADShortBufferError:	return @"Buffer was too short";
		case XADEncodingError:		return @"Text encoding was defective";
	}
	return nil;
}



-(NSString *)description
{
	return [NSString stringWithFormat:@"XADArchive: %@ (%@, %d entries)",filename,[self formatName],[self numberOfEntries]];
}



-(NSString *)nameOfEntry:(int)n
{
	XADString *xadname=[[entries objectAtIndex:n] objectForKey:XADFileNameKey];
	NSString *originalname;

	if(![originalname encodingIsKnown]&&delegate)
	{
		// TODO: Deprecate encodingForName: and replace it with encodingForData: ?
		NSStringEncoding encoding=[delegate archive:self encodingForName:[xadname cString]
		guess:[stringsource encoding] confidence:[stringsource confidence]];
		originalname=[xadname stringWithEncoding:encoding]
	}
	else originalname=[xadname string];

	// Create a mutable string
	NSMutableString *mutablename=[NSMutableString stringWithString:originalname];
//	if(!mutablename) return nil;

	// Changes backslashes to forward slashes
	NSString *separator=[[[NSString alloc] initWithBytes:"\\" length:1 encoding:[stringsource encoding]] autorelease];
	[mutablename replaceOccurrencesOfString:separator withString:@"/" options:0 range:NSMakeRange(0,[mutablename length])];

	// Clean up path
	NSMutableArray *components=[NSMutableArray arrayWithArray:[mutablename pathComponents]];

	// Drop . anywhere in the path
	for(int i=0;i<[components count];)
	{
		NSString *comp=[components objectAtIndex:i];
		if([comp isEqual:@"."]) [components removeObjectAtIndex:i];
		else i++;
	}

	// Drop all .. that can be dropped
	for(int i=1;i<[components count];)
	{
		NSString *comp1=[components objectAtIndex:i-1];
		NSString *comp2=[components objectAtIndex:i];
		if(![comp1 isEqual:@".."]&&[comp2 isEqual:@".."])
		{
			[components removeObjectAtIndex:i];
			[components removeObjectAtIndex:i-1];
			if(i>1) i--;
		}
		else i++;
	}

	// Drop slashes and .. at the start of the path
	while([components count])
	{
		NSString *first=[components objectAtIndex:0];
		if([first isEqual:@"/"]||[first isEqual:@".."]) [components removeObjectAtIndex:0];
		else break;
	}

	NSString *name=[NSString pathWithComponents:components];

	// Strip any possible .rsrc extenstion off resource forks
	// TODO: resource forks
/*	if([self _entryIsLonelyResourceFork:n])
	{
		NSString *ext=[name pathExtension];
		if(ext&&[ext isEqual:@"rsrc"]) name=[name stringByDeletingPathExtension];
	}*/

	return name;
}

-(BOOL)entryHasSize:(int)n
{
	return [entries objectForKey:XADFileSizeKey]?YES:NO;
}

-(int)sizeOfEntry:(int)n
{
	// TODO: handle files without size, &c
	// FIXME: returns 32-bit values. can't change this due to backwards compat, so what to do?
	return [[entries objectForKey:XADFileSizeKey] intValue];

/*	struct xadFileInfo *info=[self xadFileInfoForEntry:n];
	if([self _entryIsLonelyResourceFork:n]) return 0; // Special case for resource forks without data forks
	if(info->xfi_Flags&XADFIF_NOUNCRUNCHSIZE) return info->xfi_CrunchSize; // Return crunched size for files lacking an uncrunched size
	return info->xfi_Size;*/
}

-(BOOL)entryIsDirectory:(int)n
{
	NSNumber *num=[[entries objectAtIndex:n] objectForKey:XADIsDirectoryKey];
	if(num) return [num booleanValue];
	return NO;
}

-(BOOL)entryIsLink:(int)n
{
	if([[entries objectAtIndex:n] objectForKey:XADLinkDestinationKey]) return YES;
	return NO;
}

-(BOOL)entryIsEncrypted:(int)n
{
	NSNumber *num=[[entries objectAtIndex:n] objectForKey:XADIsEncryptedKey];
	if(num) return [num booleanValue];
	return NO;
}

-(BOOL)entryIsArchive:(int)n
{
	if([self numberOfEntries]==1)
	{
		NSString *ext=[[[self nameOfEntry:0] pathExtension] lowercaseString];
		if(
			[ext isEqual:@"tar"]||
			[ext isEqual:@"sit"]||
			[ext isEqual:@"sea"]||
			[ext isEqual:@"pax"]||
			[ext isEqual:@"cpio"]
		) return YES;
	}

	NSNumber *macbin=[[self propertiesForEntry:n] objectForKey:XADIsMacBinaryKey];
	if(macbin&&[macbin boolValue]) return YES;

	return NO;
}

-(BOOL)entryHasResourceFork:(int)n
{
	NSNumber *num=[[entries objectAtIndex:n] objectForKey:XADResourceSizeKey];
	if(num) return [num intValue]!=0;
	return NO;
}

-(NSDictionary *)attributesOfEntry:(int)n { return [self attributesOfEntry:n withResourceFork:NO]; }

-(NSDictionary *)attributesOfEntry:(int)n withResourceFork:(BOOL)resfork
{
	NSDictionary *props=[self propertiesForEntry:n];
	NSMutableDictionary *attrs=[NSMutableDictionary dictionary];

	NSDate *date=[props objectForKey:XADFileDateKey];
	if(date)
	{
		[attrs setObject:date forKey:NSFileCreationDate];
		[attrs setObject:date forKey:NSFileModificationDate];
	}

	NSNumber *type=[props objectForKey:XADFileTypeKey];
	if(type) [attrs setObject:type forKey:NSFileHFSTypeCode];

	NSNumber *creator=[props objectForKey:XADFileCreatorKey];
	if(creator) [attrs setObject:creator forKey:NSFileHFSCreatorCode];

	NSNumber *flags=[props objectForKey:XADFinderFlagsKey];
	if(flags) [attrs setObject:flags forKey:XADFinderFlagsKey];

	NSNumber *perm=[props objectForKey:XADFilePosixPermissionsKey];
	if(perm) [attrs setObject:perm forKey:NSFilePosixPermissions];
	else if([[self nameOfEntry:n] rangeOfString:@".app/Contents/MacOS/"].location!=NSNotFound)
	{
		// Kludge to make executables in bad app bundles without permission information executable.
		mode_t mask=umask(0); umask(mask);
		[attrs setObject:[NSNumber numberWithUnsignedShort:0777&~mask] forKey:NSFilePosixPermissions];
	}

	XADString *user=[props objectForKey:XADFilePosixUserKey];
	if(user)
	{
		NSString *username=[user string];
		if(username) [attrs setObject:username forKey:NSFileOwnerAccountName];
	}

	XADString *group=[props objectForKey:XADFilePosixGroupKey];
	if(info->xfi_GroupName)
	{
		NSString *groupname=[group string];
		if(groupname) [attrs setObject:groupname forKey:NSFileGroupOwnerAccountName];
	}

	if(resfork&&[self entryHasResourceFork:n])
	{
		NSData *forkdata;
		while(!(forkdata=[self resourceContentsOfEntry:n]))
		{
			if(delegate)
			{
				XADAction action=[delegate archive:self extractionOfResourceForkForEntryDidFail:n error:lasterror];
				if(action==XADSkip) break;
				else if(action!=XADRetry) return nil;
			}
			else return nil;
		}

		if(forkdata) [attrs setObject:forkdata forKey:XADResourceDataKey];
	}

	NSDictionary *resprops=[props objectForKey:XADDittoPropertiesKey];
	if(resprops) [self _parseDittoResourceFork:resprops intoAttributes:attrs];

	return [NSDictionary dictionaryWithDictionary:attrs];
}

-(NSData *)contentsOfEntry:(int)n
{
	@try {
		CSHandle *handle=[self handleForEntry:n];
		NSData *data=[handle remainingFileContents];
		return data; // returns nil if handle is nil
	} @catch id e {
		// TODO
		lasterror=[self parseException:e];
		return nil;
	}
}

-(NSData *)resourceContentsOfEntry:(int)n
{
	@try {
		CSHandle *handle=[self resourceHandleForEntry:n];
		NSData *data=[handle remainingFileContents];
		return data; // returns nil if handle is nil
	} @catch id e {
		// TODO
		lasterror=[self parseException:e];
		return nil;
	}
}



// Extraction functions

-(BOOL)extractTo:(NSString *)destination
{
	return [self extractEntries:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0,[self numberOfEntries])] to:destination subArchives:NO];
}

-(BOOL)extractTo:(NSString *)destination subArchives:(BOOL)sub
{
	return [self extractEntries:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0,[self numberOfEntries])] to:destination subArchives:sub];
}

-(BOOL)extractEntries:(NSIndexSet *)entries to:(NSString *)destination
{
	return [self extractEntries:entries to:destination subArchives:NO];
}

-(BOOL)extractEntries:(NSIndexSet *)entries to:(NSString *)destination subArchives:(BOOL)sub
{
	extractsize=0;
	totalsize=0;

	for(int i=[entries firstIndex];i!=NSNotFound;i=[entries indexGreaterThanIndex:i])
	totalsize+=[self sizeOfEntry:i];

	int numentries=[entries count];
	[delegate archive:self extractionProgressFiles:0 of:numentries];
	[delegate archive:self extractionProgressBytes:0 of:totalsize];

	for(int i=[entries firstIndex];i!=NSNotFound;i=[entries indexGreaterThanIndex:i])
	{
		BOOL res;

		if(sub&&[self entryIsArchive:i]) res=[self extractArchiveEntry:i to:destination];
		else res=[self extractEntry:i to:destination overrideWritePermissions:YES];

		if(!res)
		{
			totalsize=0;
			return NO;
		}

		extractsize+=[self sizeOfEntry:i];

		[delegate archive:self extractionProgressFiles:i+1 of:numentries];
		[delegate archive:self extractionProgressBytes:extractsize of:totalsize];
	}

	[self fixWritePermissions];

	totalsize=0;
	return YES;
}

-(BOOL)extractEntry:(int)n to:(NSString *)destination { return [self extractEntry:n to:destination overrideWritePermissions:NO]; }

-(BOOL)extractEntry:(int)n to:(NSString *)destination overrideWritePermissions:(BOOL)override
{
	[delegate archive:self extractionOfEntryWillStart:n];

	NSString *name;

	while(!(name=[self nameOfEntry:n]))
	{
		if(delegate)
		{
			XADAction action=[delegate archive:self nameDecodingDidFailForEntry:n bytes:[self _undecodedNameOfEntry:n]];
			if(action==XADSkip) return YES;
			else if(action!=XADRetry)
			{
				lasterror=XADBreakError;
				return NO;
			}
		}
		else
		{
			lasterror=XADEncodingError;
			return NO;
		}
	}

	if(![name length]) return YES; // Silently ignore unnamed files (or more likely, directories).

	NSDictionary *attrs=[self attributesOfEntry:n withResourceFork:YES];
	NSString *destfile=[destination stringByAppendingPathComponent:name];

	while(![self _extractEntry:n as:destfile])
	{
		if(lasterror==XADBreakError) return NO;
		else if(delegate)
		{
			XADAction action=[delegate archive:self extractionOfEntryDidFail:n error:lasterror];

			if(action==XADSkipAction) return YES;
			else if(action!=XADRetryAction) return NO;
		}
		else return NO;
	}

	if(!attrs) return NO;
	[self _changeAllAttributes:attrs atPath:destfile overrideWritePermissions:override&&[self entryIsDirectory:n]];

	[delegate archive:self extractionOfEntryDidSucceed:n];

	return YES;
}

-(BOOL)extractArchiveEntry:(int)n to:(NSString *)destination
{
	NSString *path=[destination stringByAppendingPathComponent:
	[[self nameOfEntry:n] stringByDeletingLastPathComponent]];

	XADError err;
	XADArchive *subarchive=[[XADArchive alloc] initWithArchive:self entry:n
	immediateExtractionTo:path error:&err];

	if(!subarchive)
	{
		lasterror=err;
		return NO;
	}

	err=[subarchive lastError];
	if(err) lasterror=err;

	BOOL res=![subarchive immediateExtractionFailed];

	[subarchive release];

	return res;
}

-(void)fixWritePermissions
{
	NSEnumerator *enumerator=[writeperms reverseObjectEnumerator];
	for(;;)
	{
		NSString *path=[enumerator nextObject];
		NSNumber *permissions=[enumerator nextObject];
		if(!path||!permissions) break;

		FSRef ref;
		FSCatalogInfo info;
		if(FSPathMakeRef((const UInt8 *)[path fileSystemRepresentation],&ref,NULL)!=noErr) continue;
		if(FSGetCatalogInfo(&ref,kFSCatInfoFinderInfo|kFSCatInfoPermissions|kFSCatInfoCreateDate|kFSCatInfoContentMod,&info,NULL,NULL,NULL)!=noErr) continue;

		FSPermissionInfo *pinfo=(FSPermissionInfo *)&info.permissions;
		pinfo->mode=[permissions unsignedShortValue];

		FSSetCatalogInfo(&ref,kFSCatInfoFinderInfo|kFSCatInfoPermissions|kFSCatInfoCreateDate|kFSCatInfoContentMod,&info);
	}
}



-(BOOL)_extractEntry:(int)n as:(NSString *)destfile
{
	while(![self _ensureDirectoryExists:[destfile stringByDeletingLastPathComponent]])
	{
		if(delegate)
		{
			XADAction action=[delegate archive:self creatingDirectoryDidFailForEntry:n];
			if(action==XADSkipAction) return YES;
			else if(action!=XADRetryAction)
			{
				lasterror=XADBreakError;
				return NO;
			}
		}
		else
		{
			lasterror=XADMakeDirectoryError;
			return NO;
		}
	}

	struct stat st;
	BOOL isdir=[self entryIsDirectory:n];
	BOOL islink=[self entryIsLink:n];

	if(delegate)
	while(lstat([destfile fileSystemRepresentation],&st)==0)
	{
		BOOL dir=(st.st_mode&S_IFMT)==S_IFDIR;
		NSString *newname=nil;
		XADAction action;

		if(dir)
		{
			if(isdir) return YES;
			else action=[delegate archive:self entry:n collidesWithDirectory:destfile newFilename:&newname];
		}
		else action=[delegate archive:self entry:n collidesWithFile:destfile newFilename:&newname];

		if(action==XADOverwriteAction&&!dir) break;
		else if(action==XADSkipAction) return YES;
		else if(action==XADRenameAction) destfile=[[destfile stringByDeletingLastPathComponent] stringByAppendingPathComponent:newname];
		else if(action!=XADRetryAction)
		{
			lasterror=XADBreakError;
			return NO;
		}
	}

	if(isdir) return [self _extractDirectoryEntry:n as:destfile];
	else if(islink) return [self _extractLinkEntry:n as:destfile];
	else return [self _extractFileEntry:n as:destfile];
}

static double XADGetTime()
{
	struct timeval tv;
	gettimeofday(&tv,NULL);
	return (double)tv.tv_sec+(double)tv.tv_usec/1000000.0;
}

-(BOOL)_extractFileEntry:(int)n as:(NSString *)destfile
{
	NSAutoreleasePool *pool=[NSAutoreleasePool new];

	//int fh=open([destfile fileSystemRepresentation],O_WRONLY|O_CREAT|O_TRUNC,0666);
	@try
	{
		CSHandle *desthandle=[CSFileHandle fileHandleForWritingAtPath:destfile];
		CSHandle *srchandle=[self handleForEntry:n];

		off_t total=0;
		double updatetime=0;
		uint8_t buf[65536];

		for(;;)
		{
			int actual=[srchandle readAtMost:sizeof(buf) toBuffer:buf];
			[desthandle writeBytes:actual fromBuffer:buf];
			total+=actual;

			double currtime=XADGetTime();

			if(currtime-updatetime>update_interval)
			{
				updatetime=currtime;
// TODO:
				off_t progress,filesize;
				if(![self entryHasSize:n])
				{
					progress=archive->xai_InPos-info->xpi_FileInfo->xfi_DataPos;
					filesize=info->xpi_FileInfo->xfi_CrunchSize;
				}
				else
				{
					progress=info->xpi_CurrentSize;
					filesize=info->xpi_FileInfo->xfi_Size;
				}

				[delegate archive:self extractionProgressForEntry:n bytes:progress of:filesize];
				if(totalsize)
				[delegate archive:self extractionProgressBytes:extractsize+progress of:totalsize];
				*/
			}
			if(actual!=sizeof(buf)) break;
		}
	}
	@catch id e
	{
		// TODO
		[self _handleException:e defaultError:XADOpenFileError];
		//lasterror=err;

		[pool release];
		return NO;
	}

	[pool release];
	return YES;
}

-(BOOL)_extractDirectoryEntry:(int)n as:(NSString *)destfile
{
	return [self _ensureDirectoryExists:destfile];
}

-(BOOL)_extractLinkEntry:(int)n as:(NSString *)destfile
{
	XADString *link=[[entries objectAtIndex:n] objectForKey:XADLinkDestinationKey];
	XADError err=XADERR_OK;
// TODO:
...
	char *clink=info->xfi_LinkName;
	NSString *link=[[[NSString alloc] initWithBytes:clink length:strlen(clink) encoding:[self encodingForString:clink]] autorelease];

	if(link)
	{
/*		if([[NSFileManager defaultManager] fileExistsAtPath:destfile])
		[[NSFileManager defaultManager] removeFileAtPath:destfile handler:nil];

		if(![[NSFileManager defaultManager] createSymbolicLinkAtPath:destfile pathContent:link])
		err=XADERR_OUTPUT;*/

		struct stat st;
		const char *deststr=[destfile fileSystemRepresentation];
		if(lstat(deststr,&st)==0) unlink(deststr);
		if(symlink([link fileSystemRepresentation],deststr)!=0) err=XADERR_OUTPUT;
	}
	else err=XADERR_BADPARAMS;

	if(err)
	{
		lasterror=err;
		return NO;
	}
	return YES;
}

-(BOOL)_ensureDirectoryExists:(NSString *)directory
{
	if([directory length]==0) return YES;

	struct stat st;
	if(lstat([directory fileSystemRepresentation],&st)==0)
	{
		if((st.st_mode&S_IFMT)==S_IFDIR) return YES;
		else lasterror=XADERR_MAKEDIR;
	}
	else
	{
		if([self _ensureDirectoryExists:[directory stringByDeletingLastPathComponent]])
		{
			if(!delegate||[delegate archive:self shouldCreateDirectory:directory])
			{
				if(mkdir([directory fileSystemRepresentation],0777)==0) return YES;
				else lasterror=XADERR_MAKEDIR;
			}
			else lasterror=XADERR_BREAK;
		}
	}


	return NO;
}

static NSDate *dateForJan1904()
{
	static NSDate *jan1904=nil;
	if(!jan1904) jan1904=[[NSDate dateWithString:@"1904-01-01 00:00:00 +0000"] retain];
	return jan1904;
}

static UTCDateTime NSDateToUTCDateTime(NSDate *date)
{
	NSTimeInterval seconds=[date timeIntervalSinceDate:dateForJan1904()];
	UTCDateTime utc={
		(UInt16)(seconds/4294967296.0),
		(UInt32)seconds,
		(UInt16)(seconds*65536.0)
	};
	return utc;
}

-(BOOL)_changeAllAttributes:(NSDictionary *)attrs atPath:(NSString *)path overrideWritePermissions:(BOOL)override
{
	BOOL res=YES;

	NSData *rsrcfork=[attrs objectForKey:XADResourceForkData];
	if(rsrcfork) res=[rsrcfork writeToFile:[path stringByAppendingString:@"/..namedfork/rsrc"] atomically:NO]&&res;

	FSRef ref;
	FSCatalogInfo info;
	if(FSPathMakeRef((const UInt8 *)[path fileSystemRepresentation],&ref,NULL)!=noErr) return NO;
	if(FSGetCatalogInfo(&ref,kFSCatInfoFinderInfo|kFSCatInfoPermissions|kFSCatInfoCreateDate|kFSCatInfoContentMod,&info,NULL,NULL,NULL)!=noErr) return NO;

	NSNumber *permissions=[attrs objectForKey:NSFilePosixPermissions];
	FSPermissionInfo *pinfo=(FSPermissionInfo *)&info.permissions;
	if(permissions)
	{
		pinfo->mode=[permissions unsignedShortValue];

		if(override&&!(pinfo->mode&0700))
		{
			pinfo->mode|=0700;
			[writeperms addObject:permissions];
			[writeperms addObject:path];
		}
	}

	NSDate *creation=[attrs objectForKey:NSFileCreationDate];
	NSDate *modification=[attrs objectForKey:NSFileModificationDate];

	if(creation) info.createDate=NSDateToUTCDateTime(creation);
	if(modification) info.contentModDate=NSDateToUTCDateTime(modification);

	NSNumber *type=[attrs objectForKey:NSFileHFSTypeCode];
	NSNumber *creator=[attrs objectForKey:NSFileHFSCreatorCode];
	NSNumber *finderflags=[attrs objectForKey:XADFinderFlags];
	FileInfo *finfo=(FileInfo *)&info.finderInfo;

	if(type) finfo->fileType=[type unsignedLongValue];
	if(creator) finfo->fileCreator=[creator unsignedLongValue];
	if(finderflags) finfo->finderFlags=[finderflags unsignedShortValue];

	if(FSSetCatalogInfo(&ref,kFSCatInfoFinderInfo|kFSCatInfoPermissions|kFSCatInfoCreateDate|kFSCatInfoContentMod,&info)!=noErr) return NO;

	return res;
}




// TODO
/*
-(void)setProgressInterval:(NSTimeInterval)interval
{
	update_interval=interval;
}
*/



// TODO
-(NSStringEncoding)archive:(XADArchive *)arc encodingForName:(const char *)bytes guess:(NSStringEncoding)guess confidence:(float)confidence
{ return  [self encodingForString:bytes]; }

-(XADAction)archive:(XADArchive *)arc nameDecodingDidFailForEntry:(int)n bytes:(const char *)bytes
{ return [delegate archive:arc nameDecodingDidFailForEntry:n bytes:bytes]; }

-(BOOL)archiveExtractionShouldStop:(XADArchive *)arc
{ return [delegate archiveExtractionShouldStop:arc]; }

-(BOOL)archive:(XADArchive *)arc shouldCreateDirectory:(NSString *)directory
{ return [delegate archive:arc shouldCreateDirectory:directory]; }

-(XADAction)archive:(XADArchive *)arc entry:(int)n collidesWithFile:(NSString *)file newFilename:(NSString **)newname
{ return [delegate archive:arc entry:n collidesWithFile:file newFilename:newname]; }

-(XADAction)archive:(XADArchive *)arc entry:(int)n collidesWithDirectory:(NSString *)file newFilename:(NSString **)newname
{ return [delegate archive:arc entry:n collidesWithDirectory:file newFilename:newname]; }

-(XADAction)archive:(XADArchive *)arc creatingDirectoryDidFailForEntry:(int)n
{ return [delegate archive:arc creatingDirectoryDidFailForEntry:n]; }

-(void)archive:(XADArchive *)arc extractionOfEntryWillStart:(int)n
{ [delegate archive:arc extractionOfEntryWillStart:n]; }

-(void)archive:(XADArchive *)arc extractionProgressForEntry:(int)n bytes:(xadSize)bytes of:(xadSize)total
{ [delegate archive:arc extractionProgressForEntry:n bytes:bytes of:total]; }

-(void)archive:(XADArchive *)arc extractionOfEntryDidSucceed:(int)n
{ [delegate archive:arc extractionOfEntryDidSucceed:n]; }

-(XADAction)archive:(XADArchive *)arc extractionOfEntryDidFail:(int)n error:(XADError)error
{ return [delegate archive:arc extractionOfEntryDidFail:n error:error]; }

-(XADAction)archive:(XADArchive *)arc extractionOfResourceForkForEntryDidFail:(int)n error:(XADError)error
{ return [delegate archive:arc extractionOfResourceForkForEntryDidFail:n error:error]; }

//-(void)archive:(XADArchive *)arc extractionProgressBytes:(xadSize)bytes of:(xadSize)total
//{}

//-(void)archive:(XADArchive *)arc extractionProgressFiles:(int)files of:(int)total;
//{}


@end



@implementation NSObject (XADArchiveDelegate)

-(NSStringEncoding)archive:(XADArchive *)archive encodingForName:(const char *)bytes guess:(NSStringEncoding)guess confidence:(float)confidence { return guess; }
-(XADAction)archive:(XADArchive *)archive nameDecodingDidFailForEntry:(int)n bytes:(const char *)bytes { return XADAbort; }

-(BOOL)archiveExtractionShouldStop:(XADArchive *)archive { return NO; }
-(BOOL)archive:(XADArchive *)archive shouldCreateDirectory:(NSString *)directory { return YES; }
-(XADAction)archive:(XADArchive *)archive entry:(int)n collidesWithFile:(NSString *)file newFilename:(NSString **)newname { return XADOverwrite; }
-(XADAction)archive:(XADArchive *)archive entry:(int)n collidesWithDirectory:(NSString *)file newFilename:(NSString **)newname { return XADSkip; }
-(XADAction)archive:(XADArchive *)archive creatingDirectoryDidFailForEntry:(int)n { return XADAbort; }

-(void)archive:(XADArchive *)archive extractionOfEntryWillStart:(int)n {}
-(void)archive:(XADArchive *)archive extractionProgressForEntry:(int)n bytes:(xadSize)bytes of:(xadSize)total {}
-(void)archive:(XADArchive *)archive extractionOfEntryDidSucceed:(int)n {}
-(XADAction)archive:(XADArchive *)archive extractionOfEntryDidFail:(int)n error:(XADError)error { return XADAbort; }
-(XADAction)archive:(XADArchive *)archive extractionOfResourceForkForEntryDidFail:(int)n error:(XADError)error { return XADAbort; }

-(void)archive:(XADArchive *)archive extractionProgressBytes:(xadSize)bytes of:(xadSize)total {}
-(void)archive:(XADArchive *)archive extractionProgressFiles:(int)files of:(int)total {}

@end


