#import <XADMaster/XADUnarchiver.h>

#import <sys/stat.h>

NSString *EscapeString(NSString *str)
{
	NSMutableString *res=[NSMutableString string];
	int length=[str length];
	for(int i=0;i<length;i++)
	{
		unichar c=[str characterAtIndex:i];
		if(c<32) [res appendFormat:@"^%c",c+64];
		else [res appendFormat:@"%C",c];
	}
	return res;
}

@interface Unarchiver:NSObject
{
	int indent;
}
@end

@implementation Unarchiver

-(id)initWithIndentLevel:(int)indentlevel
{
	if(self=[super init])
	{
		indent=indentlevel;
	}
	return self;
}

-(void)unarchiverNeedsPassword:(XADUnarchiver *)unarchiver
{
}

-(NSString *)unarchiver:(XADUnarchiver *)unarchiver pathForExtractingEntryWithDictionary:(NSDictionary *)dict
{
	return nil;
}

-(BOOL)unarchiver:(XADUnarchiver *)unarchiver shouldStartExtractingEntryWithDictionary:(NSDictionary *)dict to:(NSString *)path
{
	return YES;
}

-(void)unarchiver:(XADUnarchiver *)unarchiver willStartExtractingEntryWithDictionary:(NSDictionary *)dict to:(NSString *)path
{
	for(int i=0;i<indent;i++) printf(" ");

	NSNumber *dir=[dict objectForKey:XADIsDirectoryKey];
	NSNumber *link=[dict objectForKey:XADIsLinkKey];
//	NSNumber *compsize=[dict objectForKey:XADCompressedSizeKey];
	NSNumber *size=[dict objectForKey:XADFileSizeKey];
	NSNumber *rsrc=[dict objectForKey:XADIsResourceForkKey];

	NSString *name=EscapeString([[dict objectForKey:XADFileNameKey] string]);
	printf("%s (",[name UTF8String]);

	if(dir&&[dir boolValue])
	{
		printf("dir");
	}
	else if(link&&[link boolValue]) printf("link");
	else
	{
		if(size) printf("%lld",[size longLongValue]);
		else printf("?");
	}

	if(rsrc&&[rsrc boolValue]) printf(", rsrc");

	printf(")...");
	fflush(stdout);
}

-(void)unarchiver:(XADUnarchiver *)unarchiver finishedExtractingEntryWithDictionary:(NSDictionary *)dict to:(NSString *)path
{
	printf(" OK.\n");
}

-(void)unarchiver:(XADUnarchiver *)unarchiver failedToExtractEntryWithDictionary:(NSDictionary *)dict to:(NSString *)path error:(XADError)error
{
	printf(" Failed!\n");
}

-(BOOL)unarchiver:(XADUnarchiver *)unarchiver shouldCreateDirectory:(NSString *)directory
{
	return YES;
}

-(BOOL)unarchiver:(XADUnarchiver *)unarchiver shouldExtractArchiveEntryWithDictionary:(NSDictionary *)dict to:(NSString *)path
{
	return YES;
}

-(NSString *)unarchiver:(XADUnarchiver *)unarchiver linkDestinationForEntryWithDictionary:(NSDictionary *)dict from:(NSString *)path
{
	return nil;
}

-(BOOL)extractionShouldStopForUnarchiver:(XADUnarchiver *)unarchiver
{
	return NO;
}

-(void)unarchiver:(XADUnarchiver *)unarchiver extractionProgressForEntryWithDictionary:(NSDictionary *)dict
fileFraction:(double)fileprogress estimatedTotalFraction:(double)totalprogress
{
}

@end




void usage(const char *name)
{
	fprintf(stderr,"Usage: %s archive [ archive2 ... ] [ destination_directory ]\n",name);
}

int main(int argc,const char **argv)
{
	if(argc==1)
	{
		usage(argv[0]);
		return 0;
	}

	NSAutoreleasePool *pool=[NSAutoreleasePool new];

	int numfiles=argc-1;
	NSString *destination=nil;

	if(numfiles>1)
	{
		struct stat st;
		if(lstat(argv[argc-1],&st)==0)
		{
			if((st.st_mode&S_IFMT)==S_IFDIR)
			{
				destination=[NSString stringWithUTF8String:argv[argc-1]];
				numfiles--;
			}
		}
	}

	for(int i=0;i<numfiles;i++)
	{
		NSAutoreleasePool *pool=[[NSAutoreleasePool alloc] init];

		printf("Extracting %s...",argv[i+1]);
		fflush(stdout);

		NSString *filename=[NSString stringWithUTF8String:argv[i+1]];
		XADUnarchiver *unarchiver=[XADUnarchiver unarchiverForPath:filename];

		if(unarchiver)
		{
			printf("\n");

			if(destination) [unarchiver setDestination:destination];

			[unarchiver setDelegate:[[[Unarchiver alloc] initWithIndentLevel:2] autorelease]];

			//char *pass=getenv("XADTestPassword");
			//if(pass) [parser setPassword:[NSString stringWithUTF8String:pass]];

			[unarchiver parseAndUnarchive];
		}
		else
		{
			printf(" Couldn't open archive.\n");
		}

		[pool release];
	}

	[pool release];

	return 0;
}
