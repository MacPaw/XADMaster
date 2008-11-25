#import <XADMaster/XADArchiveParser.h>

@interface ArchiveTester:NSObject
{
	int indent;
}
@end

@implementation ArchiveTester

-(id)initWithIndentLevel:(int)indentlevel
{
	if(self=[super init])
	{
		indent=indentlevel;
	}
	return self;
}

-(void)archiveParser:(XADArchiveParser *)parser foundEntryWithDictionary:(NSDictionary *)dict
{
	for(int i=0;i<indent;i++) printf(" ");

	NSNumber *dir=[dict objectForKey:XADIsDirectoryKey];
	NSString *link=[dict objectForKey:XADLinkDestinationKey];
	CSHandle *fh;

	if(dir&&[dir boolValue]) printf("- ");
	else if(link) printf("- ");
	else
	{
		fh=[parser handleForEntryWithDictionary:dict wantChecksum:YES];
		NSData *data=[fh remainingFileContents];

		if(fh&&[fh hasChecksum]) printf("%c ",[fh isChecksumCorrect]?'o':'x');
		else printf("? ");
	}

	NSString *name=[[dict objectForKey:XADFileNameKey] string];
	printf("%s (",[name UTF8String]);

	if(dir&&[dir boolValue]) printf("dir");
	else if(link) printf("-> %s",[link UTF8String]);
	else
	{
		NSNumber *compsize=[dict objectForKey:XADCompressedSizeKey];
		if(compsize) printf("%lld",[compsize longLongValue]);
		else printf("?");

		printf("/");

		NSNumber *size=[dict objectForKey:XADFileSizeKey];
		if(compsize) printf("%lld",[size longLongValue]);
		else printf("?");

		NSNumber *rsrc=[dict objectForKey:XADIsResourceForkKey];
		if(rsrc&&[rsrc boolValue]) printf(", rsrc");

		if(!fh) printf(", unsupported");
	}

	printf(")\n");

	NSNumber *rsrc=[dict objectForKey:XADIsResourceForkKey];
	NSString *ext=[[name pathExtension] lowercaseString];
	if(([ext isEqual:@"sit"]||[ext isEqual:@"cpt"]||[ext isEqual:@"tar"])&&!(rsrc&&[rsrc boolValue]))
	{
		[fh seekToFileOffset:0];

		XADArchiveParser *parser=[XADArchiveParser archiveParserForHandle:fh name:name];
		[parser setDelegate:[[[ArchiveTester alloc] initWithIndentLevel:indent+2] autorelease]];
		[parser parse];
	}
}

-(BOOL)archiveParsingShouldStop:(XADArchiveParser *)parser
{
	return NO;
}

@end

int main(int argc,char **argv)
{
	for(int i=1;i<argc;i++)
	{
		NSAutoreleasePool *pool=[[NSAutoreleasePool alloc] init];

		printf("Testing %s...\n",argv[i]);

		NSString *filename=[NSString stringWithUTF8String:argv[i]];
		XADArchiveParser *parser=[XADArchiveParser archiveParserForPath:filename];

		[parser setDelegate:[[[ArchiveTester alloc] initWithIndentLevel:2] autorelease]];
		[parser setPassword:@"test"];

		@try {
			[parser parse];
		} @catch(id e) {
			NSLog(@"Exception: %@",e);
		}

		[pool release];
	}
	return 0;
}
