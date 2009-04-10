/*#include <unistd.h>
#include <sys/stat.h>
#include <dirent.h>
#include <fcntl.h>*/

#define XAD_NO_DEPRECATED

#import "XADArchive.h"
#import "CSMemoryHandle.h"
#import "CSHandle.h"
#import "CSFileHandle.h"
#import "CSZlibHandle.h"
#import "CSBzip2Handle.h"
#import "Progress.h"

#import <sys/stat.h>



NSString *XADResourceDataKey=@"XADResourceData";
NSString *XADFinderFlags=@"XADFinderFlags";



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

+(NSArray *)volumesForFile:(NSString *)filename
{
	return [XADArchiveParser volumesForFilename:(NSString *)filename];
}




-(id)init
{
	if(self=[super init])
	{
		parser=nil;
		delegate=nil;
		lasterror=XADNoError;

		entries=[[NSMutableArray array] retain];
		namedict=[[NSMutableDictionary dictionary] retain];
		writeperms=[[NSMutableArray array] retain];
 	}
	return self;
}

-(id)initWithFile:(NSString *)file { return [self initWithFile:file delegate:nil error:NULL]; }

-(id)initWithFile:(NSString *)file error:(XADError *)error { return [self initWithFile:file delegate:nil error:error]; }

-(id)initWithFile:(NSString *)file delegate:(id)del error:(XADError *)error
{
	if(self=[self init])
	{
		delegate=del;

		parser=[[XADArchiveParser archiveParserForPath:file] retain];
		if(parser)
		{
			[self _parseWithErrorPointer:error];
			return self;
		}
		else if(error) *error=XADDataFormatError;

		[self release];
	}

	return nil;
}



-(id)initWithData:(NSData *)data { return [self initWithData:data error:NULL]; }

-(id)initWithData:(NSData *)data error:(XADError *)error
{
	if(self=[self init])
	{
		delegate=nil;

		parser=[[XADArchiveParser archiveParserForHandle:[CSMemoryHandle memoryHandleForReadingData:data] name:@""] retain];
		if(!parser)
		{
			[self _parseWithErrorPointer:error];
			return self;
		}
		else if(error) *error=XADDataFormatError;

		[self release];
	}
	return nil;
}



-(id)initWithArchive:(XADArchive *)otherarchive entry:(int)n { return [self initWithArchive:otherarchive entry:n error:NULL]; }

-(id)initWithArchive:(XADArchive *)otherarchive entry:(int)n error:(XADError *)error
{
	if(self=[self init])
	{
		delegate=nil;
		parser=nil;

		CSHandle *handle=[otherarchive handleForEntry:n error:error];
		if(handle)
		{
			parser=[[XADArchiveParser archiveParserForHandle:handle name:[otherarchive nameOfEntry:n]] retain];
			if(parser)
			{
				[self _parseWithErrorPointer:error];
				return self;
			}
			else if(error) *error=XADDataFormatError;
		}

		[self release];
	}

	return nil;
}

-(id)initWithArchive:(XADArchive *)otherarchive entry:(int)n
     immediateExtractionTo:(NSString *)destination error:(XADError *)error
{
}

-(void)dealloc
{
	[parser release];
	[entries release];
	[namedict release];
	[writeperms release];

	[super dealloc];
}



-(void)_parseWithErrorPointer:(XADError *)error
{
	[parser setDelegate:self];

	@try { [parser parse]; }
	@catch(id e)
	{
		lasterror=[self _parseException:e];
		if(error) *error=lasterror;
	}
}

-(void)archiveParser:(XADArchiveParser *)parser foundEntryWithDictionary:(NSDictionary *)dict
{
	NSNumber *resnum=[dict objectForKey:XADIsResourceForkKey];
	BOOL isres=resnum&&[resnum boolValue];

	XADString *name=[dict objectForKey:XADFileNameKey];

	NSNumber *index=[namedict objectForKey:name];
	if(index) // Try to update an existing entry
	{
		NSMutableDictionary *entry=[entries objectAtIndex:[index intValue]];
		if(isres)
		{
			if(![entry objectForKey:@"ResourceFork"])
			{
				[entry setObject:dict forKey:@"ResourceFork"];
				return;
			}
		}
		else
		{
			if(![entry objectForKey:@"DataFork"])
			{
				[entry setObject:dict forKey:@"DataFork"];
				return;
			}
		}
	}

	// Create a new entry instead

	if(isres) [entries addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:
		dict,@"ResourceFork",
		[NSNumber numberWithBool:YES],@"ResourceForkFirst",
	nil]];
	else [entries addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:
		dict,@"DataFork",
	nil]];

	[namedict setObject:[NSNumber numberWithInt:[entries count]] forKey:name];
}

-(BOOL)archiveParsingShouldStop:(XADArchiveParser *)parser
{
	return NO; // TODO: actually figure out how to use this
}

/*
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


-(NSString *)filename
{
	return [parser filename];
}

-(NSArray *)allFilenames
{
	return [parser allFilenames];
}

-(NSString *)formatName
{
	/*if(parentarchive) return [NSString stringWithFormat:@"%@ in %@",[parser formatName],[parentarchive formatName]];
	else*/ return [parser formatName];
}

-(BOOL)isEncrypted { return NO; } // TODO

-(BOOL)isSolid { return NO; } // TODO

-(BOOL)isCorrupted { return NO; } // TODO

-(int)numberOfEntries { return [entries count]; }

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



-(NSString *)password { return [parser password]; }

-(void)setPassword:(NSString *)newpassword { [parser setPassword:newpassword]; }



-(NSStringEncoding)nameEncoding { return [[parser stringSource] encoding]; }

-(void)setNameEncoding:(NSStringEncoding)encoding { [[parser stringSource] setFixedEncoding:encoding]; }




-(XADError)lastError { return lasterror; }

-(void)clearLastError { lasterror=XADNoError; }

-(NSString *)describeLastError { return [XADException describeXADError:lasterror]; }

-(NSString *)describeError:(XADError)error { return [XADException describeXADError:error]; }



-(NSString *)description
{
	return [NSString stringWithFormat:@"XADArchive: %@ (%@, %d entries)",[self filename],[self formatName],[self numberOfEntries]];
}



-(NSDictionary *)dataForkParserDictionaryForEntry:(int)n
{
	return [[entries objectAtIndex:n] objectForKey:@"DataFork"];
}

-(NSDictionary *)resourceForkParserDictionaryForEntry:(int)n
{
	return [[entries objectAtIndex:n] objectForKey:@"ResourceFork"];
}

-(NSDictionary *)freshestParserDictionaryForEntry:(int)n
{
	NSDictionary *entry=[entries objectAtIndex:n];
	if([entry objectForKey:@"ResourceForkFirst"])
	{
		NSDictionary *dict=[entry objectForKey:@"DataFork"];
		if(!dict) return [entry objectForKey:@"ResourceFork"];
		else return dict;
	}
	else
	{
		NSDictionary *dict=[entry objectForKey:@"ResourceFork"];
		if(!dict) return [entry objectForKey:@"DataFork"];
		else return dict;
	}
}

-(NSString *)nameOfEntry:(int)n
{
	NSDictionary *dict=[self dataForkParserDictionaryForEntry:n];
	if(!dict) dict=[self resourceForkParserDictionaryForEntry:n];
	XADString *xadname=[dict objectForKey:XADFileNameKey];
	if(!xadname) return nil;

	NSString *originalname;

	if(![xadname encodingIsKnown]&&delegate)
	{
		NSStringEncoding encoding=[delegate archive:self encodingForName:[xadname cString]
		guess:[xadname encoding] confidence:[xadname confidence]];
		originalname=[xadname stringWithEncoding:encoding];
	}
	else originalname=[xadname string];

	if(!originalname) return nil;

	// Create a mutable string
	NSMutableString *mutablename=[NSMutableString stringWithString:originalname];

	// Changes backslashes to forward slashes
	NSString *separator=[[[NSString alloc] initWithBytes:"\\" length:1 encoding:[xadname encoding]] autorelease];
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

	return name;
}

-(BOOL)entryHasSize:(int)n
{
	NSDictionary *dict=[self dataForkParserDictionaryForEntry:n];
	return [dict objectForKey:XADFileSizeKey]?YES:NO;
}

-(int)sizeOfEntry:(int)n
{
	// TODO: figure out exactly how this should work
	NSDictionary *dict=[self dataForkParserDictionaryForEntry:n];
	if(!dict) return 0; // Special case for resource forks without data forks
	NSNumber *size=[dict objectForKey:XADFileSizeKey];
	if(!size) return 0x7fffffff;

	return [size intValue];

/*	struct xadFileInfo *info=[self xadFileInfoForEntry:n];
	if([self _entryIsLonelyResourceFork:n]) return 0; // Special case for resource forks without data forks
	if(info->xfi_Flags&XADFIF_NOUNCRUNCHSIZE) return info->xfi_CrunchSize; // Return crunched size for files lacking an uncrunched size
	return info->xfi_Size;*/
}

-(BOOL)entryIsDirectory:(int)n
{
	NSDictionary *dict=[self dataForkParserDictionaryForEntry:n];
	NSNumber *isdir=[dict objectForKey:XADIsDirectoryKey];

	return isdir&&[isdir boolValue];
}

-(BOOL)entryIsLink:(int)n
{
	NSDictionary *dict=[self dataForkParserDictionaryForEntry:n];
	NSNumber *islink=[dict objectForKey:XADIsLinkKey];

	return islink&&[islink boolValue];
}

-(BOOL)entryIsEncrypted:(int)n
{
	NSDictionary *dict=[self dataForkParserDictionaryForEntry:n];
	NSNumber *isenc=[dict objectForKey:XADIsEncryptedKey];

	return isenc&&[isenc boolValue];
}

-(BOOL)entryIsArchive:(int)n
{
	NSDictionary *dict=[self dataForkParserDictionaryForEntry:n];
	NSNumber *isarc=[dict objectForKey:XADIsArchiveKey];

	return isarc&&[isarc boolValue];
}

-(BOOL)entryHasResourceFork:(int)n
{
	NSDictionary *resdict=[self resourceForkParserDictionaryForEntry:n];
	if(!resdict) return NO;
	NSNumber *num=[resdict objectForKey:XADFileSizeKey];
	if(!num) return NO;

	return [num intValue]!=0;
}

-(NSDictionary *)attributesOfEntry:(int)n { return [self attributesOfEntry:n withResourceFork:NO]; }

-(NSDictionary *)attributesOfEntry:(int)n withResourceFork:(BOOL)resfork
{
	NSDictionary *dict=[self freshestParserDictionaryForEntry:n];
	NSMutableDictionary *attrs=[NSMutableDictionary dictionary];

	NSDate *creation=[dict objectForKey:XADCreationDateKey];
	NSDate *modification=[dict objectForKey:XADLastModificationDateKey];
	if(creation&&modification)
	{
		[attrs setObject:creation forKey:NSFileCreationDate];
		[attrs setObject:modification forKey:NSFileModificationDate];
	}
	else if(modification)
	{
		[attrs setObject:modification forKey:NSFileCreationDate];
		[attrs setObject:modification forKey:NSFileModificationDate];
	}
	else if(creation)
	{
		[attrs setObject:creation forKey:NSFileCreationDate];
		[attrs setObject:creation forKey:NSFileModificationDate];
	}

	NSNumber *type=[dict objectForKey:XADFileTypeKey];
	if(type) [attrs setObject:type forKey:NSFileHFSTypeCode];

	NSNumber *creator=[dict objectForKey:XADFileCreatorKey];
	if(creator) [attrs setObject:creator forKey:NSFileHFSCreatorCode];

	NSNumber *flags=[dict objectForKey:XADFinderFlagsKey];
	if(flags) [attrs setObject:flags forKey:XADFinderFlagsKey];

	NSNumber *perm=[dict objectForKey:XADPosixPermissionsKey];
	if(perm) [attrs setObject:perm forKey:NSFilePosixPermissions];

	XADString *user=[dict objectForKey:XADPosixUserKey];
	if(user)
	{
		NSString *username=[user string];
		if(username) [attrs setObject:username forKey:NSFileOwnerAccountName];
	}

	XADString *group=[dict objectForKey:XADPosixGroupKey];
	if(group)
	{
		NSString *groupname=[group string];
		if(groupname) [attrs setObject:groupname forKey:NSFileGroupOwnerAccountName];
	}

	if(resfork)
	{
		NSDictionary *resdict=[self resourceForkParserDictionaryForEntry:n];
		if(resdict)
		{
			for(;;)
			{
				@try
				{
					CSHandle *handle=[parser handleForEntryWithDictionary:resdict wantChecksum:YES];
					if(!handle) [XADException raiseDecrunchException];
					NSData *forkdata=[handle remainingFileContents];
					if([handle hasChecksum]&&![handle isChecksumCorrect]) [XADException raiseChecksumException];

					[attrs setObject:forkdata forKey:XADResourceDataKey];
					break;
				}
				@catch(id e)
				{
					lasterror=[self _parseException:e];
					XADAction action=[delegate archive:self extractionOfResourceForkForEntryDidFail:n error:lasterror];
					if(action==XADSkipAction) break;
					else if(action!=XADRetryAction) return nil;
				}
			}
		}
	}

	return [NSDictionary dictionaryWithDictionary:attrs];
}

-(CSHandle *)handleForEntry:(int)n
{
	return [self handleForEntry:n error:NULL];
}

-(CSHandle *)handleForEntry:(int)n error:(XADError *)error
{
	NSDictionary *dict=[self dataForkParserDictionaryForEntry:n];
	if(!dict) return [CSMemoryHandle memoryHandleForReadingData:[NSData data]]; // Special case for files with only a resource fork

	@try
	{ return [parser handleForEntryWithDictionary:dict wantChecksum:YES]; }
	@catch(id e)
	{
		lasterror=[self _parseException:e];
		if(error) *error=lasterror;
	}
	return nil;
}

-(CSHandle *)resourceHandleForEntry:(int)n
{
	return [self resourceHandleForEntry:n error:NULL];
}

-(CSHandle *)resourceHandleForEntry:(int)n error:(XADError *)error
{
	NSDictionary *resdict=[self resourceForkParserDictionaryForEntry:n];
	if(!resdict) return nil;

	@try
	{ return [parser handleForEntryWithDictionary:resdict wantChecksum:YES]; }
	@catch(id e)
	{
		lasterror=[self _parseException:e];
		if(error) *error=lasterror;
	}
	return nil;
}

-(NSData *)contentsOfEntry:(int)n
{
	NSDictionary *dict=[self dataForkParserDictionaryForEntry:n];
	if(!dict) return [NSData data]; // Special case for files with only a resource fork

	@try
	{
		CSHandle *handle=[parser handleForEntryWithDictionary:dict wantChecksum:YES];
		if(!handle) [XADException raiseDecrunchException];
		NSData *data=[handle remainingFileContents];
		if([handle hasChecksum]&&![handle isChecksumCorrect]) [XADException raiseChecksumException];

		return data;
	}
	@catch(id e)
	{
		lasterror=[self _parseException:e];
	}
	return nil;
}

-(XADError)_parseException:(id)exception
{
	if([exception isKindOfClass:[NSException class]])
	{
		NSException *e=exception;
		NSString *name=[e name];
		if([name isEqual:XADExceptionName])
		{
			return [[[e userInfo] objectForKey:@"XADError"] intValue];
		}
		else if([name isEqual:CSFileErrorException])
		{
			return XADUnknownError; // TODO: use ErrNo in userInfo to figure out better error
		}
		else if([name isEqual:CSOutOfMemoryException]) return XADOutOfMemoryError;
		else if([name isEqual:CSEndOfFileException]) return XADInputError;
		else if([name isEqual:CSNotImplementedException]) return XADNotSupportedError;
		else if([name isEqual:CSNotSupportedException]) return XADNotSupportedError;
		else if([name isEqual:CSZlibException]) return XADDecrunchError;
		else if([name isEqual:CSBzip2Exception]) return XADDecrunchError;
	}

	return XADUnknownError;
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

-(BOOL)extractEntries:(NSIndexSet *)entryset to:(NSString *)destination
{
	return [self extractEntries:entryset to:destination subArchives:NO];
}

-(BOOL)extractEntries:(NSIndexSet *)entryset to:(NSString *)destination subArchives:(BOOL)sub
{
	extractsize=0;
	totalsize=0;

	for(int i=[entryset firstIndex];i!=NSNotFound;i=[entryset indexGreaterThanIndex:i])
	totalsize+=[self sizeOfEntry:i];

	int numentries=[entryset count];
	[delegate archive:self extractionProgressFiles:0 of:numentries];
	[delegate archive:self extractionProgressBytes:0 of:totalsize];

	for(int i=[entryset firstIndex];i!=NSNotFound;i=[entryset indexGreaterThanIndex:i])
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
			XADAction action=[delegate archive:self nameDecodingDidFailForEntry:n
			data:[[[self dataForkParserDictionaryForEntry:n] objectForKey:XADFileNameKey] data]];
			if(action==XADSkipAction) return YES;
			else if(action!=XADRetryAction)
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

	if(![self _changeAllAttributesForEntry:(int)n atPath:destfile overrideWritePermissions:override&&[self entryIsDirectory:n]]) return NO;

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

	int fh=open([destfile fileSystemRepresentation],O_WRONLY|O_CREAT|O_TRUNC,0666);
	if(!fh)
	{
		lasterror=XADOpenFileError;
		[pool release];
		return NO;
	}

	@try
	{
		CSHandle *srchandle=[self handleForEntry:n];

		off_t size=[self sizeOfEntry:n]; // TODO: use proper size!
		BOOL hassize=[self entryHasSize:n];

		off_t done=0;
		double updatetime=0;
		uint8_t buf[65536];

		for(;;)
		{
			int actual=[srchandle readAtMost:sizeof(buf) toBuffer:buf];
			if(write(fh,buf,actual)!=actual)
			{
				lasterror=XADOutputError;
				[pool release];
				return NO;
			}

			done+=actual;

			double currtime=XADGetTime();
			if(currtime-updatetime>update_interval)
			{
				updatetime=currtime;

				off_t progress;
				if(hassize) progress=done;
				else progress=size*[srchandle estimatedProgress];

				[delegate archive:self extractionProgressForEntry:n bytes:progress of:size];
				if(totalsize)
				[delegate archive:self extractionProgressBytes:extractsize+progress of:totalsize];
			}
			if(actual!=sizeof(buf)) break;
		}
	}
	@catch(id e)
	{
		lasterror=[self _parseException:e];
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
	XADString *xadlink=[parser linkDestinationForDictionary:[self dataForkParserDictionaryForEntry:n]];
	NSString *link;
	if(![xadlink encodingIsKnown]&&delegate)
	{
		// TODO: should there be a better way to deal with encodings?
		NSStringEncoding encoding=[delegate archive:self encodingForName:[xadlink cString]
		guess:[xadlink encoding] confidence:[xadlink confidence]];
		link=[xadlink stringWithEncoding:encoding];
	}
	else link=[xadlink string];

	XADError err=XADNoError;

	if(link)
	{
/*		if([[NSFileManager defaultManager] fileExistsAtPath:destfile])
		[[NSFileManager defaultManager] removeFileAtPath:destfile handler:nil];

		if(![[NSFileManager defaultManager] createSymbolicLinkAtPath:destfile pathContent:link])
		err=XADERR_OUTPUT;*/

		struct stat st;
		const char *deststr=[destfile fileSystemRepresentation];
		if(lstat(deststr,&st)==0) unlink(deststr);
		if(symlink([link fileSystemRepresentation],deststr)!=0) err=XADOutputError;
	}
	else err=XADBadParametersError;

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
		else lasterror=XADMakeDirectoryError;
	}
	else
	{
		if([self _ensureDirectoryExists:[directory stringByDeletingLastPathComponent]])
		{
			if(!delegate||[delegate archive:self shouldCreateDirectory:directory])
			{
				if(mkdir([directory fileSystemRepresentation],0777)==0) return YES;
				else lasterror=XADMakeDirectoryError;
			}
			else lasterror=XADBreakError;
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

-(BOOL)_changeAllAttributesForEntry:(int)n atPath:(NSString *)path overrideWritePermissions:(BOOL)override
{
	CSHandle *rsrchandle=[self resourceHandleForEntry:n];
	if(rsrchandle) @try
	{
		NSData *data=[rsrchandle remainingFileContents];
		if([rsrchandle hasChecksum]&&![rsrchandle isChecksumCorrect]) [XADException raiseChecksumException];

		// TODO: use xattrs?
		if(![data writeToFile:[path stringByAppendingString:@"/..namedfork/rsrc"] atomically:NO]) return NO;
	}
	@catch(id e)
	{
		lasterror=[self _parseException:e];
		return NO;
	}

	NSDictionary *dict=[self freshestParserDictionaryForEntry:n];

	FSRef ref;
	FSCatalogInfo info;
	if(FSPathMakeRef((const UInt8 *)[path fileSystemRepresentation],&ref,NULL)!=noErr) return NO;
	if(FSGetCatalogInfo(&ref,kFSCatInfoFinderInfo|kFSCatInfoPermissions|kFSCatInfoCreateDate|kFSCatInfoContentMod|kFSCatInfoAccessDate,&info,NULL,NULL,NULL)!=noErr) return NO;

	NSNumber *permissions=[dict objectForKey:XADPosixPermissionsKey];
	FSPermissionInfo *pinfo=(FSPermissionInfo *)&info.permissions;
	if(permissions)
	{
		pinfo->mode=[permissions unsignedShortValue];

		if(override)
		{
			pinfo->mode|=0700;
			[writeperms addObject:permissions];
			[writeperms addObject:path];
		}
	}

	NSDate *creation=[dict objectForKey:XADCreationDateKey];
	NSDate *modification=[dict objectForKey:XADLastModificationDateKey];
	NSDate *access=[dict objectForKey:XADLastAccessDateKey];

	if(creation) info.createDate=NSDateToUTCDateTime(creation);
	if(modification) info.contentModDate=NSDateToUTCDateTime(modification);
	if(access) info.accessDate=NSDateToUTCDateTime(access);

	// TODO: Handle FinderInfo structure
	NSNumber *type=[dict objectForKey:XADFileTypeKey];
	NSNumber *creator=[dict objectForKey:XADFileCreatorKey];
	NSNumber *finderflags=[dict objectForKey:XADFinderFlagsKey];
	FileInfo *finfo=(FileInfo *)&info.finderInfo;

	if(type) finfo->fileType=[type unsignedLongValue];
	if(creator) finfo->fileCreator=[creator unsignedLongValue];
	if(finderflags) finfo->finderFlags=[finderflags unsignedShortValue];

	if(FSSetCatalogInfo(&ref,kFSCatInfoFinderInfo|kFSCatInfoPermissions|kFSCatInfoCreateDate|kFSCatInfoContentMod|kFSCatInfoAccessDate,&info)!=noErr) return NO;

	return YES;
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
		if(FSGetCatalogInfo(&ref,kFSCatInfoPermissions,&info,NULL,NULL,NULL)!=noErr) continue;

		FSPermissionInfo *pinfo=(FSPermissionInfo *)&info.permissions;
		pinfo->mode=[permissions unsignedShortValue];

		FSSetCatalogInfo(&ref,kFSCatInfoPermissions,&info);
	}
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

-(void)archive:(XADArchive *)arc extractionProgressForEntry:(int)n bytes:(off_t)bytes of:(off_t)total
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

-(NSStringEncoding)archive:(XADArchive *)archive encodingForData:(NSData *)data guess:(NSStringEncoding)guess confidence:(float)confidence
{
	// Default implementation calls old method
	NSMutableData *terminateddata=[[NSMutableData alloc] dataWithData:data];
	NSStringEncoding enc=[self archive:archive encodingForName:[terminateddata bytes] guess:guess confidence:confidence];
	[terminateddata release];
	return enc;
}

-(XADAction)archive:(XADArchive *)archive nameDecodingDidFailForEntry:(int)n data:(NSData *)data
{
	// Default implementation calls old method
	NSMutableData *terminateddata=[[NSMutableData alloc] dataWithData:data];
	XADAction action=[self archive:archive nameDecodingDidFailForEntry:n bytes:[terminateddata bytes]];
	[terminateddata release];
	return action;
}

-(BOOL)archiveExtractionShouldStop:(XADArchive *)archive { return NO; }
-(BOOL)archive:(XADArchive *)archive shouldCreateDirectory:(NSString *)directory { return YES; }
-(XADAction)archive:(XADArchive *)archive entry:(int)n collidesWithFile:(NSString *)file newFilename:(NSString **)newname { return XADOverwriteAction; }
-(XADAction)archive:(XADArchive *)archive entry:(int)n collidesWithDirectory:(NSString *)file newFilename:(NSString **)newname { return XADSkipAction; }
-(XADAction)archive:(XADArchive *)archive creatingDirectoryDidFailForEntry:(int)n { return XADAbortAction; }

-(void)archive:(XADArchive *)archive extractionOfEntryWillStart:(int)n {}
-(void)archive:(XADArchive *)archive extractionProgressForEntry:(int)n bytes:(off_t)bytes of:(off_t)total {}
-(void)archive:(XADArchive *)archive extractionOfEntryDidSucceed:(int)n {}
-(XADAction)archive:(XADArchive *)archive extractionOfEntryDidFail:(int)n error:(XADError)error { return XADAbortAction; }
-(XADAction)archive:(XADArchive *)archive extractionOfResourceForkForEntryDidFail:(int)n error:(XADError)error { return XADAbortAction; }

-(void)archive:(XADArchive *)archive extractionProgressBytes:(off_t)bytes of:(off_t)total {}
-(void)archive:(XADArchive *)archive extractionProgressFiles:(int)files of:(int)total {}

// Deprecated
-(NSStringEncoding)archive:(XADArchive *)archive encodingForName:(const char *)bytes guess:(NSStringEncoding)guess confidence:(float)confidence { return guess; }
-(XADAction)archive:(XADArchive *)archive nameDecodingDidFailForEntry:(int)n bytes:(const char *)bytes { return XADAbortAction; }

@end


