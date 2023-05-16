#include <stdio.h>

#import "XADSimpleUnarchiver.h"
#import "NSStringPrinting.h"
#import "CSCommandLineParser.h"
#import "CommandLineCommon.h"
#import "CSFileHandle.h"

FILE *outstream,*errstream;

NSAutoreleasePool *shared_pool = NULL;

void __attribute__ ((constructor)) my_init(void);
void __attribute__ ((destructor)) my_fini(void);

void my_init(void) {
	printf("shared object entering now PRE\n");
	printf("POSSSSSST\n");
}

void my_fini(void) {
	printf("shared object leaving now\n");
	if( shared_pool ) {
		[shared_pool release];
	}
	printf("SHOWED\n");
}

#define DEF_SETTER(VARIABLE) \
void \
ArchiveSet ## VARIABLE (Archive * a, const char * __ ## VARIABLE ##__ ) { \
	NSString *__ ## VARIABLE ## __ns = [NSString stringWithUTF8String: __## VARIABLE ##__ ]; \
	[a->unarchiver set##VARIABLE: __## VARIABLE ##__ns]; \
} \

#define DEF_SETTER_BOOLEAN(VARIABLE) \
void ArchiveSet##VARIABLE (Archive *a, bool __## VARIABLE ##__) { \
	BOOL __## VARIABLE ##__ns = (BOOL) __## VARIABLE ##__ ; \
	[a->unarchiver set##VARIABLE: __## VARIABLE ##__ns]; \
} \

@interface NULLLister:NSObject {
	@public NSMutableArray *entries;
}
@end

@interface NULLUnarchiver:NSObject {
	@public NSMutableArray *entries;
}
@end

typedef struct Archive {
	const char * path;
	const char * password;
	const char * encoding;
	char * lastError;

	XADSimpleUnarchiver *unarchiver;
} Archive;

typedef struct Entry {
	char * path;
	char *filename;
	int dirP;
	int linkP;
	int resourceP;
	int corruptedP;
	int encryptedP;
	unsigned long eid;
	const char * encoding;
	char * renaming;
	unsigned size;
} Entry;

void _check_pool() {
	if( !shared_pool ) {
		shared_pool = [NSAutoreleasePool new];
	}
}

Archive * ArchiveNew(const char * path, const char * password, const char * encoding) {
	_check_pool();
	XADError openerror;
	NSString *filename=[NSString stringWithUTF8String:path];

	XADSimpleUnarchiver *unarchiver=[XADSimpleUnarchiver simpleUnarchiverForPath:filename error:&openerror];

	if(!unarchiver)
	{
		if(openerror)
		{
			//[@"Couldn't open archive. (" printToFile:errstream];
			//[[XADException describeXADError:openerror] printToFile:errstream];
			//[@".)\n" printToFile:errstream];
			return NULL;
		}

		//[@"Couldn't recognize the archive format.\n" printToFile:errstream];
		return NULL;
	}

	Archive * ret = (Archive*)calloc(1, sizeof(Archive));
	ret->path = path;
	ret->password = password;
	ret->encoding = encoding;
	ret->unarchiver = unarchiver;

	return ret;
}

// void ArchiveSetDestination(const char * dest) {
// 	NSString *destination=[NSString stringWithUTF8String:dest];
// 	[unarchiver setDestination:destination];
// }

// void ArchiveSetPassword(const char * password) {
// 	NSString *pass=[NSString stringWithUTF8String:password];
// 	[unarchiver setPassword:pass];
// }

// Continue with macro definitions
DEF_SETTER(Destination)
DEF_SETTER(Password)
DEF_SETTER(EncodingName)
DEF_SETTER(PasswordEncodingName)

DEF_SETTER_BOOLEAN(AlwaysOverwritesFiles)
DEF_SETTER_BOOLEAN(AlwaysRenamesFiles)
DEF_SETTER_BOOLEAN(AlwaysSkipsFiles)
DEF_SETTER_BOOLEAN(ExtractsSubArchives)
DEF_SETTER_BOOLEAN(PropagatesRelevantMetadata)
DEF_SETTER_BOOLEAN(CopiesArchiveModificationTimeToEnclosingDirectory)
DEF_SETTER_BOOLEAN(MacResourceForkStyle)
DEF_SETTER_BOOLEAN(PerIndexRenamedFiles)

// TODO: solve forcedirectory [unarchiver setRemovesEnclosingDirectoryForSoloItems:NO];
// TODO: solve forcedirectory [unarchiver setEnclosingDirectoryName:nil];

Entry ** ArchiveList(Archive * archive) {
	_check_pool();

	NSString *path=[NSString stringWithUTF8String:archive->path];
	NULLLister *lister = [[[NULLLister alloc] init] autorelease];
	[archive->unarchiver setDelegate:lister];
	XADError parseerror=[archive->unarchiver parse];

	if(parseerror)
	{
		[@"Archive parsing failed! (" print];
		[[XADException describeXADError:parseerror] print];
		[@".)\n" print];
		return NULL;
	}

	XADError unarchiveerror=[archive->unarchiver unarchive];

	if(unarchiveerror)
	{
		[@"Listing failed! (" print];
		[[XADException describeXADError:unarchiveerror] print];
		[@".)\n" print];
		return NULL;
	}

	int numentries = [lister->entries count];
	Entry ** ret = (Entry**)calloc(numentries+1, sizeof(Entry*));

	printf("PARSING...\n");

	for(int i=0; i < numentries; i++) {
		Entry * entry = calloc(1, sizeof(Entry));
		NSDictionary * dict = [lister->entries objectAtIndex:i];
		NSString *filename = [[dict objectForKey:XADFileNameKey] string];
		NSNumber *dirnum=[dict objectForKey:XADIsDirectoryKey];
		NSNumber *linknum=[dict objectForKey:XADIsLinkKey];
		NSNumber *resnum=[dict objectForKey:XADIsResourceForkKey];
		NSNumber *corruptednum=[dict objectForKey:XADIsCorruptedKey];
		NSNumber *sizenum=[dict objectForKey:XADFileSizeKey];
		NSNumber *indexnum=[dict objectForKey:XADIndexKey];
		NSNumber *encryptednum=[dict objectForKey:XADIsEncryptedKey];

		entry->filename = [filename UTF8String];
		entry->eid = [indexnum intValue];
		entry->dirP = [dirnum intValue] != 0;
		entry->linkP = [linknum intValue] != 0;
		entry->resourceP = [resnum intValue] != 0;
		entry->corruptedP = [corruptednum intValue] != 0;
		entry->size = (size_t)[sizenum intValue];
		entry->encryptedP = [encryptednum intValue] != 0;

		ret[i] = entry;
	}


	return ret;
}

unsigned ArchiveExtract(Archive * a, Entry ** ens) {
	_check_pool();

	unsigned numentries = 0;

	NULLUnarchiver *unarchiverDelegate = [[[NULLUnarchiver alloc] init] autorelease];
	[a->unarchiver setDelegate:unarchiverDelegate];

	while(*ens) {
		Entry * e = *ens;

		if (e->renaming) {
			[a->unarchiver setPerIndexRenamedFiles:YES];
			printf("Renaming id %u. %s to %s\n", e->eid, e->filename, e->renaming);
			[a->unarchiver addIndexFilter:e->eid];
			NSString *nsrename = [NSString stringWithUTF8String:e->renaming];
			[a->unarchiver addIndexRenaming:nsrename];
		}
		else {
			printf("Not Renaming...\n");
			[a->unarchiver addIndexFilter:e->eid];
		}

		ens++;
		numentries++;
	}

	XADError unarchiveerror = [a->unarchiver unarchive];

	if(unarchiveerror)
	{
		if(unarchiveerror) {} //[[XADException describeXADError:unarchiveerror] printToFile:errstream];
	}

	return numentries;
}


#define EntryDoesNotNeedTestingResult 0
#define EntryIsNotSupportedResult 1
#define EntryHasWrongPasswordResult 2
#define EntryFailsWhileUnpackingResult 3
#define EntrySizeIsWrongResult 4
#define EntryHasNoChecksumResult 5
#define EntryChecksumIsIncorrectResult 6
#define EntryIsOkResult 7

static int TestEntry(XADSimpleUnarchiver *unarchiver, NSDictionary *dict)
{
	unsigned returncode = 0;
	NSNumber *dir=[dict objectForKey:XADIsDirectoryKey];
	NSNumber *link=[dict objectForKey:XADIsLinkKey];
	NSNumber *size=[dict objectForKey:XADFileSizeKey];

	BOOL isdir=dir&&[dir boolValue];
	BOOL islink=link&&[link boolValue];

	if(isdir||islink) return EntryDoesNotNeedTestingResult;

	XADArchiveParser *parser=[unarchiver archiveParser];
	XADError error;
	CSHandle *handle=[parser handleForEntryWithDictionary:dict wantChecksum:YES error:&error];

	if(!handle)
	{
		returncode=1;
		if(error==XADPasswordError) return EntryHasWrongPasswordResult;
		else return EntryIsNotSupportedResult;
	}

	@try
	{
		[handle seekToEndOfFile];
	}
	@catch(id exception)
	{
		returncode=1;
		return EntryFailsWhileUnpackingResult;
	}

	if(![handle hasChecksum])
	{
		if(size&&[size longLongValue]!=[handle offsetInFile])
		{
			returncode=1;
			return EntrySizeIsWrongResult;
		}
		else
		{
			return EntryHasNoChecksumResult;
		}
	}
	else
	{
		if(![handle isChecksumCorrect])
		{
			returncode=1;
			return EntryChecksumIsIncorrectResult;
		}
		else if(size&&[size longLongValue]!=[handle offsetInFile])
		{
			returncode=1;
			return EntrySizeIsWrongResult; // Unlikely to happen
		}
		else
		{
			return EntryIsOkResult;
		}
	}

	return returncode;
}


@implementation NULLLister

- (id)init
{
	if(self = [super init])
	{
		if(!entries) entries=[NSMutableArray new];
	}

	return self;
}


-(void)simpleUnarchiverNeedsPassword:(XADSimpleUnarchiver *)unarchiver
{
	// Just print an error to stderr to indicate a password is needed, ignored however.
	// [@"NULLLister: This archive requires a password to unpack. Set password to provide one.\n" printToFile:stderr];
}

-(BOOL)simpleUnarchiver:(XADSimpleUnarchiver *)unarchiver shouldExtractEntryWithDictionary:(NSDictionary *)dict to:(NSString *)path
{
	[entries addObject:dict];
	return NO;
}



@end

@implementation NULLUnarchiver


-(void)simpleUnarchiverNeedsPassword:(XADSimpleUnarchiver *)unarchiver
{
	// Just print an error to stderr to indicate a password is needed, ignored however.
	[@"NULLLister: This archive requires a password to unpack. Set password to provide one.\n" print];
}




@end