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

// void my_init(void) {
// 	printf("shared object entering now PRE\n");
// 	printf("POSSSSSST\n");
// }

// void my_fini(void) {
// 	printf("shared object leaving now\n");
// 	if( shared_pool ) {
// 		//[shared_pool release];
// 		printf("SHOWED\n");
// 	}
// }

#define DEF_SETTER(VARIABLE) \
void \
ArchiveSet ## VARIABLE (Archive * a, const char * __ ## VARIABLE ##__ ) { \
	NSString *__ ## VARIABLE ## __ns = [NSString stringWithUTF8String: __## VARIABLE ##__ ]; \
	[a->unarchiver set##VARIABLE: __## VARIABLE ##__ns]; \
} \

#define DEF_SETTER_BOOLEAN(VARIABLE) \
void ArchiveSet ## VARIABLE (Archive *a, int __## VARIABLE ##__) { \
	BOOL __## VARIABLE ##__ns = (BOOL) __## VARIABLE ##__ ; \
	[a->unarchiver set##VARIABLE: __## VARIABLE ##__ns]; \
} \

@interface NULLLister:NSObject {
	@public NSMutableArray *entries;
}
@end

@interface NULLUnarchiver:NSObject {
	@public NSMutableArray *xadErrors;
	@public NSMutableArray *xadDescriptions;
	@public NSMutableArray *dicts;
}
@end

typedef enum ArchiveError {
	NO_ERROR = 0,
	OPEN = 1,
	FORMAT = 2,
	PASSWORD = 3,

	ENTRY_ENCODING,
	ENTRY_BROKEN_RECORD,
	ENTRY_NO_PASSWORD,
	ENTRY_WRONG_PASSWORD,
	ENTRY_UNPACKING_ERROR,
	ENTRY_NOT_SUPPORTED,
	ENTRY_WRONG_SIZE,
	ENTRY_HAS_NO_CHECKSUM,
	ENTRY_CHECKSUM_INCORRECT,

	OTHER = 255
} ArchiveError;

typedef struct EntryError {
	ArchiveError error_num;
	char * error_str;
	int eid;
} EntryError;

EntryError * EntryErrorNew(EntryError e) {
	EntryError * ret = malloc(sizeof(EntryError));
	memcpy(ret, &e, sizeof(EntryError));
	if(e.error_str) {
		ret->error_str = strdup(e.error_str);
	}

	return ret;
}

void EntryErrorDestroy(EntryError * e) {
	free(e->error_str);
	free(e);
}

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
	char * error_string;

	unsigned size;
} Entry;

typedef struct Archive {
	char * path;

	char * error_str;
	ArchiveError error_num;

	XADSimpleUnarchiver *unarchiver;
} Archive;

void _check_pool() {
	if( !shared_pool ) {
		shared_pool = [NSAutoreleasePool new];
	}
}

Archive * ArchiveNew(const char * path) {
	_check_pool();
	XADError openerror;
	NSString *filename=[NSString stringWithUTF8String:path];
	Archive * ret = (Archive*)calloc(1, sizeof(Archive));
	ret->path = strdup(path);

	XADSimpleUnarchiver *unarchiver=[XADSimpleUnarchiver simpleUnarchiverForPath:filename error:&openerror];
	if(!unarchiver)
	{
		if(openerror)
		{
			ret->error_num = OPEN;
			ret->error_str = [[XADException describeXADError:openerror] UTF8String];

			return ret;
		}

		ret->error_num = FORMAT;
		ret->error_str = [@"Couldn't recognize the archive format.\n" UTF8String];

		return ret;
	}

	ret->unarchiver = unarchiver;
	return ret;
}

void ArchiveDestroy(Archive * a) {
	free(a->error_str);
	free(a->path);

  [a->unarchiver release];
	a->unarchiver = NULL;

	free(a);
}

// Generating output like this
// void ArchiveSetDestination(const char * dest) {
// 	NSString *destination=[NSString stringWithUTF8String:dest];
// 	[unarchiver setDestination:destination];
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
		[@"ERROR: " print];
		[[XADException describeXADError:unarchiveerror] print];
	}

	return numentries;
}

static ArchiveError TestEntry(XADSimpleUnarchiver *unarchiver, NSDictionary *dict)
{
	NSNumber *dir=[dict objectForKey:XADIsDirectoryKey];
	NSNumber *link=[dict objectForKey:XADIsLinkKey];
	NSNumber *size=[dict objectForKey:XADFileSizeKey];

	BOOL isdir=dir&&[dir boolValue];
	BOOL islink=link&&[link boolValue];

	if(isdir||islink) return NO_ERROR;

	XADArchiveParser *parser=[unarchiver archiveParser];
	XADError error;
	CSHandle *handle=[parser handleForEntryWithDictionary:dict wantChecksum:YES error:&error];

	if(!handle)
	{
		if(error==XADPasswordError) return ENTRY_WRONG_PASSWORD;
		else return ENTRY_NOT_SUPPORTED;
	}

	@try
	{
		[handle seekToEndOfFile];
	}
	@catch(id exception)
	{
		return ENTRY_UNPACKING_ERROR;
	}

	if(![handle hasChecksum])
	{
		if(size&&[size longLongValue]!=[handle offsetInFile])
		{
			return ENTRY_WRONG_SIZE;
		}
		else
		{
			return ENTRY_HAS_NO_CHECKSUM;
		}
	}
	else
	{
		if(![handle isChecksumCorrect])
		{
			return ENTRY_CHECKSUM_INCORRECT;
		}
		else if(size&&[size longLongValue]!=[handle offsetInFile])
		{
			return ENTRY_WRONG_SIZE;
		}
		else
		{
			return NO_ERROR;
		}
	}

	return NO_ERROR;
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

- (id)init
{
	if(self = [super init])
	{
		xadErrors=[NSMutableArray new];
		xadDescriptions=[NSMutableArray new];
		dicts=[NSMutableArray new];
	}

	return self;
}


-(void)simpleUnarchiverNeedsPassword:(XADSimpleUnarchiver *)unarchiver
{
	// Just print an error to stderr to indicate a password is needed, ignored however.
	/*int i;
	scanf("No password %d\n", &i);*/
}

-(void)simpleUnarchiver:(XADSimpleUnarchiver *)unarchiver didExtractEntryWithDictionary:(NSDictionary *)dict to:(NSString *)path error:(XADError)error
{
	if(error)
	{
		[xadErrors addObject:[[NSNumber alloc] initWithInt:error]];
		[xadDescriptions addObject:[XADException describeXADError:error]];
		[dicts addObject:dict];
	}
}


@end
