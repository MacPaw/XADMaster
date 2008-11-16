#import "XADArchiveParser.h"
#import "CSFileHandle.h"

#import "XADZipParser.h"
#import "XADGZipParser.h"
#import "XADLibXADParser.h"

const NSString *XADFileNameKey=@"XADFileName";
const NSString *XADFileSizeKey=@"XADFileSize";
const NSString *XADCompressedSizeKey=@"XADCompressedSize";
const NSString *XADLastModificationDateKey=@"XADLastModificationDate";
const NSString *XADLastAccessDateKey=@"XADLastAccessDate";
const NSString *XADCreationDateKey=@"XADCreationDate";
const NSString *XADFileTypeKey=@"XADFileType";
const NSString *XADFileCreatorKey=@"XADFileCreator";
const NSString *XADFinderFlagsKey=@"XADFinderFlags";
const NSString *XADPosixPermissionsKey=@"XADPosixPermissions";
const NSString *XADPosixUserKey=@"XADPosixUser";
const NSString *XADPosixGroupKey=@"XADGroupUser";
const NSString *XADPosixUserNameKey=@"XADPosixUser";
const NSString *XADPosixGroupNameKey=@"XADGroupUser";
const NSString *XADIsEncryptedKey=@"XADIsEncrypted";
const NSString *XADIsDirectoryKey=@"XADIsDirectory";
const NSString *XADIsMacBinaryKey=@"XADIsMacBinary";
const NSString *XADLinkDestinationKey=@"XADLinkDestination";
const NSString *XADCommentKey=@"XADComment";
const NSString *XADDataOffsetKey=@"XADDataOffset";
const NSString *XADCompressionNameKey=@"XADCompressionName";


@implementation XADArchiveParser

static NSMutableArray *parserclasses=nil;
static int maxheader=0;

+(void)initialize
{
	if(parserclasses) return;
	parserclasses=[[NSMutableArray arrayWithObjects:
		[XADZipParser class],
		[XADGZipParser class],
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
	if(!parserclasses) return nil;
	NSData *header=[handle readDataOfLengthAtMost:maxheader];

	NSEnumerator *enumerator=[parserclasses objectEnumerator];
	Class parserclass;
	while(parserclass=[enumerator nextObject])
	{
		[handle seekToFileOffset:0];
		if([parserclass recognizeFileWithHandle:handle firstBytes:header name:name])
		{
			[handle seekToFileOffset:0];
			return [[[parserclass alloc] initWithHandle:handle name:name] autorelease];
		}
	}
	return nil;
}

+(XADArchiveParser *)archiveParserForPath:(NSString *)filename
{
	CSFileHandle *fh;

	@try {
		fh=[CSFileHandle fileHandleForReadingAtPath:filename];
	} @catch(id e) { return nil; }

	return [self archiveParserForHandle:fh name:filename];
}



-(id)initWithHandle:(CSHandle *)handle name:(NSString *)name
{
	if(self=[super init])
	{
		sourcehandle=[handle retain];
		archivename=[[name lastPathComponent] retain];

		delegate=nil;
		password=nil;
		isencrypted=NO;

		stringsource=[XADStringSource new];
	}
	return self;
}

-(void)dealloc
{
	[sourcehandle release];
	[archivename release];
	[stringsource release];
	[super dealloc];
}

-(id)delegate { return delegate; }

-(void)setDelegate:(id)newdelegate { delegate=newdelegate; }

-(BOOL)isEncrypted { return isencrypted; }

-(void)setPassword:(NSString *)newpassword
{
	[password autorelease];
	password=[newpassword retain];
}



-(CSHandle *)handle { return sourcehandle; }

-(CSHandle *)handleAtDataOffsetForDictionary:(NSDictionary *)dict
{
	[sourcehandle seekToFileOffset:[[dict objectForKey:XADDataOffsetKey] longLongValue]];
	return sourcehandle;
}

-(NSString *)name { return archivename; }

-(void)addEntryWithDictionary:(NSDictionary *)dictionary
{
	// If an encrypted file is added, set the global encryption flag
	NSNumber *num=[dictionary objectForKey:XADIsEncryptedKey];
	if(num&&[num boolValue]) [self setEncrypted:YES];

	[delegate archiveParser:self foundEntryWithDictionary:dictionary];
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

-(XADString *)XADStringWithCString:(const void *)string
{
	return [stringsource XADStringWithData:[NSData dataWithBytes:string length:strlen(string)]];
}

-(XADString *)XADStringWithCString:(const void *)string encoding:(NSStringEncoding)encoding
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

-(void)setEncrypted:(BOOL)encryptedflag
{
	isencrypted=encryptedflag;
}


+(int)requiredHeaderSize { return 0; }
+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name { return NO; }

-(void)parse {}
-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)properties { return nil; }
-(NSString *)formatName { return nil; }

@end


@implementation NSObject (XADArchiveParserDelegate)

-(void)archiveParser:(XADArchiveParser *)parser foundEntryWithDictionary:(NSDictionary *)dict {}
-(BOOL)archiveParsingShouldStop:(XADArchiveParser *)parser { return NO; }

@end


