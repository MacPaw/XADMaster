#import "XADArchiveParser.h"
#import "CSFileHandle.h"



CSHandle *HandleForLocators(NSArray *locators,NSString **nameptr);

@interface EntryFinder:NSObject
{
	int count,entrynum;
	NSDictionary *entry;
}
-(id)initWithLocator:(NSString *)string;
@end




int main(int argc,char **argv)
{
	NSAutoreleasePool *pool=[NSAutoreleasePool new];

	if(argc==2)
	{
		NSString *filename=[NSString stringWithUTF8String:argv[1]];
		NSArray *locators=[filename componentsSeparatedByString:@":"];
		CSHandle *fh=HandleForLocators(locators,NULL);
		if(!fh)
		{
			fprintf(stderr,"Failed to open %s.\n",argv[1]);
			exit(1);
		}

		off_t size=0;
		while(![fh atEndOfFile])
		{
			uint8_t b=[fh readUInt8];
			putc(b,stdout);
			size++;
		}
		fflush(stdout);

		fprintf(stderr,"\nRead %lld bytes from %s.\n",size,argv[1]);
	}
	else if(argc==3)
	{
		NSString *filename1=[NSString stringWithUTF8String:argv[1]];
		NSString *filename2=[NSString stringWithUTF8String:argv[2]];
		NSArray *locators1=[filename1 componentsSeparatedByString:@":"];
		NSArray *locators2=[filename2 componentsSeparatedByString:@":"];

		CSHandle *fh1=HandleForLocators(locators1,NULL);
		if(!fh1)
		{
			fprintf(stderr,"Failed to open %s.\n",argv[1]);
			exit(1);
		}

		CSHandle *fh2=HandleForLocators(locators2,NULL);
		if(!fh2)
		{
			fprintf(stderr,"Failed to open %s.\n",argv[2]);
			exit(1);
		}

		off_t size=0;
		while(![fh1 atEndOfFile] && ![fh2 atEndOfFile])
		{
			uint8_t b1=[fh1 readUInt8];
			uint8_t b2=[fh2 readUInt8];

			if(b1!=b2)
			{
				fprintf(stderr,"Mismatch between %s and %s, starting at byte "
				"%lld (%02x vs. %02x).\n",argv[1],argv[2],size,b1,b2);
				exit(1);
			}

			size++;
		}

		if(![fh1 atEndOfFile])
		{
			fprintf(stderr,"%s ended before %s, after %lld bytes.\n",argv[2],argv[1],size);
			exit(1);
		}
		else if(![fh2 atEndOfFile])
		{
			fprintf(stderr,"%s ended before %s, after %lld bytes.\n",argv[1],argv[2],size);
			exit(1);
		}

		fprintf(stderr,"Read %lld bytes from %s and %s, which are identical.\n",
		size,argv[1],argv[2]);
	}
	else
	{
		printf("Usage: %s file[:archiveentry[:...]] [comparefile[:archiveentry[:...]]]\n",argv[0]);
		exit(1);
	}

	[pool release];
	
	return 0;
}



@implementation EntryFinder

CSHandle *HandleForLocators(NSArray *locators,NSString **nameptr)
{
	if([locators count]==1)
	{
		NSString *filename=[locators lastObject];
		if(nameptr) *nameptr=filename;

		return [CSFileHandle fileHandleForReadingAtPath:filename];
	}
	else
	{
		NSString *locator=[locators lastObject];
		NSArray *parentlocators=[locators subarrayWithRange:NSMakeRange(0,[locators count]-1)];

		NSString *parentname;
		CSHandle *parenthandle=HandleForLocators(parentlocators,&parentname);
		if(!parenthandle) return nil;

		XADArchiveParser *parser=[XADArchiveParser archiveParserForHandle:parenthandle name:parentname];

		char *pass=getenv("XADTestPassword");
		if(pass) [parser setPassword:[NSString stringWithUTF8String:pass]];

		EntryFinder *finder=[[[EntryFinder alloc] initWithLocator:locator] autorelease];
		[parser setDelegate:finder];

		[parser parse];

		if(!finder->entry) return nil;

		if(nameptr) *nameptr=[[finder->entry objectForKey:XADFileNameKey] string];
		return [parser handleForEntryWithDictionary:finder->entry wantChecksum:YES];
	}
}

-(id)initWithLocator:(NSString *)locator
{
	if(self=[super init])
	{
		count=-1;
		entrynum=-1;
		entry=nil;

		NSArray *matches=[locator substringsCapturedByPattern:@"^#([0-9]+)$"];
		if(matches)
		{
			entrynum=[[matches objectAtIndex:1] intValue];
		}
		else
		{
		}
	}
	return self;
}

-(void)dealloc
{
	[entry release];
	[super dealloc];
}

-(void)archiveParser:(XADArchiveParser *)parser foundEntryWithDictionary:(NSDictionary *)dict
{
	count++;

	NSNumber *dir=[dict objectForKey:XADIsDirectoryKey];
	NSNumber *link=[dict objectForKey:XADIsLinkKey];

	if(entrynum>=0 && entrynum==count)
	{
		entry=[dict retain];
		return;
	}

	if(dir&&[dir boolValue]) return;
	else if(link&&[link boolValue]) return;

}

-(BOOL)archiveParsingShouldStop:(XADArchiveParser *)parser
{
	return entry!=nil;
}

@end
