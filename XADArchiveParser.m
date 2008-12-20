#import "XADArchiveParser.h"
#import "CSFileHandle.h"
#import "CSMultiHandle.h"

#import "XADZipParser.h"
#import "XADRARParser.h"
#import "XAD7ZipParser.h"
#import "XADGzipParser.h"
#import "XADBzip2Parser.h"
#import "XADLZMAParser.h"
#import "XADXARParser.h"
#import "XADStuffItParser.h"
#import "XADStuffIt5Parser.h"
#import "XADBinHexParser.h"
#import "XADCompactProParser.h"
#import "XADCompressParser.h"
#import "XADALZipParser.h"
#import "XADPowerPackerParser.h"
#import "XADLZMAAloneParser.h"
#import "XADLibXADParser.h"

#include <dirent.h>

NSString *XADFileNameKey=@"XADFileName";
NSString *XADFileSizeKey=@"XADFileSize";
NSString *XADCompressedSizeKey=@"XADCompressedSize";
NSString *XADLastModificationDateKey=@"XADLastModificationDate";
NSString *XADLastAccessDateKey=@"XADLastAccessDate";
NSString *XADCreationDateKey=@"XADCreationDate";
NSString *XADFileTypeKey=@"XADFileType";
NSString *XADFileCreatorKey=@"XADFileCreator";
NSString *XADFinderFlagsKey=@"XADFinderFlags";
NSString *XADFinderInfoKey=@"XADFinderInfo";
NSString *XADPosixPermissionsKey=@"XADPosixPermissions";
NSString *XADPosixUserKey=@"XADPosixUser";
NSString *XADPosixGroupKey=@"XADGroupUser";
NSString *XADPosixUserNameKey=@"XADPosixUserName";
NSString *XADPosixGroupNameKey=@"XADGroupUserName";
NSString *XADDOSFileAttributesKey=@"XADDOSFileAttributes";
NSString *XADWindowsFileAttributesKey=@"XADWindowsFileAttributes";
NSString *XADIsEncryptedKey=@"XADIsEncrypted";
NSString *XADIsDirectoryKey=@"XADIsDirectory";
NSString *XADIsLinkKey=@"XADIsLink";
NSString *XADIsResourceForkKey=@"XADIsResourceFork";
NSString *XADIsMacBinaryKey=@"XADIsMacBinary";
NSString *XADLinkDestinationKey=@"XADLinkDestination";
NSString *XADCommentKey=@"XADComment";
NSString *XADDataOffsetKey=@"XADDataOffset";
NSString *XADDataLengthKey=@"XADDataLength";
NSString *XADCompressionNameKey=@"XADCompressionName";
NSString *XADIsSolidKey=@"XADIsSolid";
NSString *XADFirstSolidEntryKey=@"XADFirstSolidEntry";
NSString *XADNextSolidEntryKey=@"XADNextSolidEntry";

NSString *XADArchiveNameKey=@"XADArchiveName";
NSString *XADIsCorruptedKey=@"XADIsCorrupted";


@implementation XADArchiveParser

static NSMutableArray *parserclasses=nil;
static int maxheader=0;

+(void)initialize
{
	if(parserclasses) return;
	parserclasses=[[NSMutableArray arrayWithObjects:
		[XADZipParser class],
		[XADRARParser class],
		[XAD7ZipParser class],
		[XADGzipParser class],
		[XADBzip2Parser class],
		[XADLZMAParser class],
		[XADXARParser class],
		[XADStuffIt5Parser class],
		[XADStuffItParser class],
		[XADBinHexParser class],
		[XADCompactProParser class],
		[XADCompressParser class],
		[XADALZipParser class],
		[XADPowerPackerParser class],
		[XADLZMAAloneParser class],
		[XADLibXADParser class],
	nil] retain];

	NSEnumerator *enumerator=[parserclasses objectEnumerator];
	Class class;
	while(class=[enumerator nextObject])
	{
		int header=[class requiredHeaderSize];
		if(header>maxheader) maxheader=header;
	}
}

+(XADArchiveParser *)archiveParserForHandle:(CSHandle *)handle name:(NSString *)name
{
	NSData *header=[handle readDataOfLengthAtMost:maxheader];
	NSEnumerator *enumerator=[parserclasses objectEnumerator];
	Class parserclass;
	while(parserclass=[enumerator nextObject])
	{
		[handle seekToFileOffset:0];
		@try {
			if([parserclass recognizeFileWithHandle:handle firstBytes:header name:name])
			{
				[handle seekToFileOffset:0];
				return [[[parserclass alloc] initWithHandle:handle name:name] autorelease];
			}
		} @catch(id e) {} // ignore parsers that throw errors on recognition or init
	}
	return nil;
}

+(XADArchiveParser *)archiveParserForPath:(NSString *)filename
{
	CSHandle *handle;

	NSArray *volumes=[self volumesForFilename:filename];
	if(volumes)
	{
		@try
		{
			NSMutableArray *handles=[NSMutableArray array];
			NSEnumerator *enumerator=[volumes objectEnumerator];
			NSString *volume;

			while(volume=[enumerator nextObject])
			[handles addObject:[CSFileHandle fileHandleForReadingAtPath:volume]];

			return [self archiveParserForHandle:[CSMultiHandle multiHandleWithHandleArray:handles]
			name:[volumes objectAtIndex:0]];
		}
		@catch(id e) { }
	}

	trysingle:
	@try {
		handle=[CSFileHandle fileHandleForReadingAtPath:filename];
	} @catch(id e) { return nil; }

	return [self archiveParserForHandle:handle name:filename];
}


static int XADVolumeSort(NSString *str1,NSString *str2,void *classptr)
{
	Class parserclass=classptr;
	BOOL isfirst1=[parserclass isFirstVolume:str1];
	BOOL isfirst2=[parserclass isFirstVolume:str2];

	if(isfirst1&&!isfirst2) return NSOrderedAscending;
	else if(!isfirst1&&isfirst2) return NSOrderedDescending;
//	else return [str1 compare:str2 options:NSCaseInsensitiveSearch|NSNumericSearch];
	else return [str1 compare:str2 options:NSCaseInsensitiveSearch];
}

+(NSArray *)volumesForFilename:(NSString *)name
{
	NSEnumerator *enumerator=[parserclasses objectEnumerator];
	Class parserclass;
	while(parserclass=[enumerator nextObject])
	{
		XADRegex *regex=[parserclass volumeRegexForFilename:name];
		if(!regex) continue;

		NSMutableArray *volumes=[NSMutableArray array];

		NSString *dirname=[name stringByDeletingLastPathComponent];
		if(!dirname||[dirname length]==0) dirname=@".";

		DIR *dir=opendir([dirname fileSystemRepresentation]);
		if(!dir) return nil;

		struct dirent *ent;
		while(ent=readdir(dir))
		{
			NSString *filename=[dirname stringByAppendingPathComponent:[NSString stringWithUTF8String:ent->d_name]];
			if([regex matchesString:filename]) [volumes addObject:filename];
		}

		closedir(dir);

		[volumes sortUsingFunction:XADVolumeSort context:parserclass];

		if([volumes count]>1) return volumes;
	}
	return nil;
}





-(id)initWithHandle:(CSHandle *)handle name:(NSString *)name
{
	if(self=[super init])
	{
		sourcehandle=[handle retain];

		skiphandle=nil;
		delegate=nil;
		password=nil;

		properties=[[NSMutableDictionary alloc] initWithObjectsAndKeys:
			[self XADStringWithString:[name lastPathComponent]],XADArchiveNameKey,
		nil];

		stringsource=[XADStringSource new];
	}
	return self;
}

-(void)dealloc
{
	[sourcehandle release];
	[skiphandle release];
	[stringsource release];
	[properties release];
	[super dealloc];
}



-(NSDictionary *)properties { return properties; }

-(NSString *)name { return [[properties objectForKey:XADArchiveNameKey] string]; }

-(BOOL)isEncrypted
{
	NSNumber *isencrypted=[properties objectForKey:XADIsEncryptedKey];
	return isencrypted&&[isencrypted boolValue];
}



-(id)delegate { return delegate; }

-(void)setDelegate:(id)newdelegate { delegate=newdelegate; }

-(NSString *)password { return password; }

-(void)setPassword:(NSString *)newpassword
{
	[password autorelease];
	password=[newpassword retain];
}



-(XADString *)linkDestinationForDictionary:(NSDictionary *)dictionary
{
	NSNumber *islink=[dictionary objectForKey:XADIsLinkKey];
	if(!islink||![islink boolValue]) return nil;

	XADString *linkdest=[dictionary objectForKey:XADLinkDestinationKey];
	if(linkdest) return linkdest;

	CSHandle *handle=[self handleForEntryWithDictionary:dictionary wantChecksum:YES];
	NSData *linkdata=[handle remainingFileContents];
	if([handle hasChecksum]&&![handle isChecksumCorrect]) return nil; // TODO: do something else here?

	return [self XADStringWithData:linkdata];
}





-(CSHandle *)handle { return sourcehandle; }

-(CSHandle *)handleAtDataOffsetForDictionary:(NSDictionary *)dict
{
	CSHandle *handle=skiphandle?skiphandle:sourcehandle;

	[handle seekToFileOffset:[[dict objectForKey:XADDataOffsetKey] longLongValue]];

	NSNumber *length=[dict objectForKey:XADDataLengthKey];
	if(length) return [handle nonCopiedSubHandleOfLength:[length longLongValue]];
	else return handle;
}

-(XADSkipHandle *)skipHandle
{
	if(!skiphandle) skiphandle=[[XADSkipHandle alloc] initWithHandle:sourcehandle];
	return skiphandle;
}



-(NSArray *)volumes
{
	if([sourcehandle respondsToSelector:@selector(handles)]) return [(id)sourcehandle handles];
	else return nil;
}

-(off_t)offsetForVolume:(int)disk offset:(off_t)offset
{
	if([sourcehandle respondsToSelector:@selector(handles)])
	{
		NSArray *handles=[(id)sourcehandle handles];
		int count=[handles count];
		for(int i=0;i<count&&i<disk;i++) offset+=[[handles objectAtIndex:i] fileSize];
	}

	return offset;
}



-(void)setObject:(id)object forPropertyKey:(NSString *)key { [properties setObject:object forKey:key]; }



-(void)addEntryWithDictionary:(NSMutableDictionary *)dictionary
{
	[self addEntryWithDictionary:dictionary retainPosition:NO];
}

-(void)addEntryWithDictionary:(NSMutableDictionary *)dictionary retainPosition:(BOOL)retainpos
{
	// If an encrypted file is added, set the global encryption flag
	NSNumber *enc=[dictionary objectForKey:XADIsEncryptedKey];
	if(enc&&[enc boolValue]) [self setObject:[NSNumber numberWithBool:YES] forPropertyKey:XADIsEncryptedKey];

	// Same for the corrupted flag
	NSNumber *cor=[dictionary objectForKey:XADIsCorruptedKey];
	if(cor&&[cor boolValue]) [self setObject:[NSNumber numberWithBool:YES] forPropertyKey:XADIsCorruptedKey];

	// LinkDestination implies IsLink
	XADString *linkdest=[dictionary objectForKey:XADLinkDestinationKey];
	if(linkdest) [dictionary setObject:[NSNumber numberWithBool:YES] forKey:XADIsLinkKey];

	if(retainpos)
	{
		off_t pos=[sourcehandle offsetInFile];
		[delegate archiveParser:self foundEntryWithDictionary:dictionary];
		[sourcehandle seekToFileOffset:pos];
	}
	else [delegate archiveParser:self foundEntryWithDictionary:dictionary];
}


-(XADString *)XADStringWithString:(NSString *)string
{
	return [stringsource XADStringWithString:string];
}

-(XADString *)XADStringWithData:(NSData *)data
{
	return [stringsource XADStringWithData:data];
}

-(XADString *)XADStringWithData:(NSData *)data encoding:(NSStringEncoding)encoding
{
	return [XADString XADStringWithString:[[[NSString alloc] initWithData:data encoding:encoding] autorelease]];
}

-(XADString *)XADStringWithBytes:(const void *)bytes length:(int)length
{
	return [stringsource XADStringWithData:[NSData dataWithBytes:bytes length:length]];
}

-(XADString *)XADStringWithBytes:(const void *)bytes length:(int)length encoding:(NSStringEncoding)encoding
{
	return [XADString XADStringWithString:[[[NSString alloc] initWithData:
	[NSData dataWithBytes:bytes length:length] encoding:encoding] autorelease]];
}

-(XADString *)XADStringWithCString:(const char *)string
{
	return [stringsource XADStringWithData:[NSData dataWithBytes:string length:strlen(string)]];
}

-(XADString *)XADStringWithCString:(const char *)string encoding:(NSStringEncoding)encoding
{
	return [XADString XADStringWithString:[[[NSString alloc] initWithData:
	[NSData dataWithBytes:string length:strlen(string)] encoding:encoding] autorelease]];
}

-(NSData *)encodedPassword
{
	if(!password) return [NSData data];
	else return [password dataUsingEncoding:[stringsource encoding]];
}

-(const char *)encodedCStringPassword
{
	NSMutableData *data=[NSMutableData dataWithData:[self encodedPassword]];
	[data increaseLengthBy:1];
	return [data bytes];
}



+(int)requiredHeaderSize { return 0; }
+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name { return NO; }
+(XADRegex *)volumeRegexForFilename:(NSString *)filename { return nil; }
+(BOOL)isFirstVolume:(NSString *)filename { return NO; }

-(void)parse {}
-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dictionary wantChecksum:(BOOL)checksum { return nil; }
-(NSString *)formatName { return nil; }

@end


@implementation NSObject (XADArchiveParserDelegate)

-(void)archiveParser:(XADArchiveParser *)parser foundEntryWithDictionary:(NSDictionary *)dict {}
-(BOOL)archiveParsingShouldStop:(XADArchiveParser *)parser { return NO; }

@end
