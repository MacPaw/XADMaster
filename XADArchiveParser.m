#import "XADArchiveParser.h"
#import "CSFileHandle.h"
#import "CSMultiHandle.h"

#import "XADZipParser.h"
#import "XADRARParser.h"
#import "XAD7ZipParser.h"
#import "XADGzipParser.h"
#import "XADBzip2Parser.h"
#import "XADLZMAParser.h"
#import "XADPPMdParser.h"
#import "XADXARParser.h"
#import "XADStuffItParser.h"
#import "XADStuffIt5Parser.h"
#import "XADStuffItXParser.h"
#import "XADBinHexParser.h"
#import "XADCompactProParser.h"
#import "XADDiskDoublerParser.h"
#import "XADPackItParser.h"
#import "XADCompressParser.h"
#import "XADRPMParser.h"
#import "XADALZipParser.h"
#import "XADLHAParser.h"
#import "XADPowerPackerParser.h"
#import "XADLZMAAloneParser.h"
#import "XADTarParser.h"
#import "XADCpioParser.h"
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
NSString *XADIsCorruptedKey=@"XADIsCorrupted";
NSString *XADIsDirectoryKey=@"XADIsDirectory";
NSString *XADIsResourceForkKey=@"XADIsResourceFork";
NSString *XADIsArchiveKey=@"XADIsArchive";
NSString *XADIsLinkKey=@"XADIsLink";
NSString *XADIsHardLinkKey=@"XADIsHardLink";
NSString *XADLinkDestinationKey=@"XADLinkDestination";
NSString *XADIsCharacterDeviceKey=@"XADIsCharacterDevice";
NSString *XADIsBlockDeviceKey=@"XADIsBlockDevice";
NSString *XADDeviceMajorKey=@"XADDeviceMajor";
NSString *XADDeviceMinorKey=@"XADDeviceMinor";
NSString *XADIsFIFOKey=@"XADIsFIFO";

NSString *XADCommentKey=@"XADComment";
NSString *XADDataOffsetKey=@"XADDataOffset";
NSString *XADDataLengthKey=@"XADDataLength";
NSString *XADCompressionNameKey=@"XADCompressionName";

NSString *XADIsSolidKey=@"XADIsSolid";
NSString *XADFirstSolidEntryKey=@"XADFirstSolidEntry";
NSString *XADNextSolidEntryKey=@"XADNextSolidEntry";

NSString *XADArchiveNameKey=@"XADArchiveName";


@implementation XADArchiveParser

static NSMutableArray *parserclasses=nil;
static int maxheader=0;

+(void)initialize
{
	static BOOL hasinitialized=NO;
	if(hasinitialized) return;
	hasinitialized=YES;

	parserclasses=[[NSMutableArray arrayWithObjects:
		[XADZipParser class],
		[XADRARParser class],
		[XAD7ZipParser class],
		[XADGzipParser class],
		[XADBzip2Parser class],
		[XADLZMAParser class],
		[XADPPMdParser class],
		[XADXARParser class],
		[XADStuffItParser class],
		[XADStuffIt5Parser class],
		[XADStuffIt5ExeParser class],
		[XADStuffItXParser class],
		[XADBinHexParser class],
		[XADCompactProParser class],
		[XADDiskDoublerParser class],
		[XADPackItParser class],
		[XADCompressParser class],
		[XADRPMParser class],
		[XADALZipParser class],
		[XADLHAParser class],
		[XADPowerPackerParser class],
		[XADLZMAAloneParser class],
		[XADCpioParser class],
		[XADTarParser class],
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

		stringsource=[XADStringSource new];

		properties=[[NSMutableDictionary alloc] initWithObjectsAndKeys:
			[self XADStringWithString:[name lastPathComponent]],XADArchiveNameKey,
		nil];
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



-(XADString *)linkDestinationForDictionary:(NSDictionary *)dict
{
	NSNumber *islink=[dict objectForKey:XADIsLinkKey];
	if(!islink||![islink boolValue]) return nil;

	XADString *linkdest=[dict objectForKey:XADLinkDestinationKey];
	if(linkdest) return linkdest;

	CSHandle *handle=[self handleForEntryWithDictionary:dict wantChecksum:YES];
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



-(void)addEntryWithDictionary:(NSMutableDictionary *)dict
{
	[self addEntryWithDictionary:dict retainPosition:NO];
}

-(void)addEntryWithDictionary:(NSMutableDictionary *)dict retainPosition:(BOOL)retainpos
{
	// If an encrypted file is added, set the global encryption flag
	NSNumber *enc=[dict objectForKey:XADIsEncryptedKey];
	if(enc&&[enc boolValue]) [self setObject:[NSNumber numberWithBool:YES] forPropertyKey:XADIsEncryptedKey];

	// Same for the corrupted flag
	NSNumber *cor=[dict objectForKey:XADIsCorruptedKey];
	if(cor&&[cor boolValue]) [self setObject:[NSNumber numberWithBool:YES] forPropertyKey:XADIsCorruptedKey];

	// LinkDestination implies IsLink
	XADString *linkdest=[dict objectForKey:XADLinkDestinationKey];
	if(linkdest) [dict setObject:[NSNumber numberWithBool:YES] forKey:XADIsLinkKey];

	// Extract type, creator and finderflags from finderinfo
	NSData *finderinfo=[dict objectForKey:XADFinderInfoKey];
	if(finderinfo&&[finderinfo length]>=10)
	{
		const uint8_t *bytes=[finderinfo bytes];
		uint32_t type=CSUInt32BE(bytes+0);
		uint32_t creator=CSUInt32BE(bytes+4);
		int flags=CSUInt16BE(bytes+8);

		if(type) [dict setObject:[NSNumber numberWithUnsignedInt:type] forKey:XADFileTypeKey];
		if(creator) [dict setObject:[NSNumber numberWithUnsignedInt:type] forKey:XADFileCreatorKey];
		[dict setObject:[NSNumber numberWithInt:flags] forKey:XADFinderFlagsKey];
	}

	if(retainpos)
	{
		off_t pos=[sourcehandle offsetInFile];
		[delegate archiveParser:self foundEntryWithDictionary:dict];
		[sourcehandle seekToFileOffset:pos];
	}
	else [delegate archiveParser:self foundEntryWithDictionary:dict];
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
-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum { return nil; }
-(NSString *)formatName { return nil; } // TODO: combine names for nested archives

@end


@implementation NSObject (XADArchiveParserDelegate)

-(void)archiveParser:(XADArchiveParser *)parser foundEntryWithDictionary:(NSDictionary *)dict {}
-(BOOL)archiveParsingShouldStop:(XADArchiveParser *)parser { return NO; }

@end
