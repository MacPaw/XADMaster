/*
 * libSimpleUnar.m
 *
 * Copyright (c) 2023, SpongeData s.r.o. All rights reserved.
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
 * MA 02110-1301  USA
 */
#include <stdio.h>

#define __LIBXAD_PRIVATE_PART 1
#include "libXADMaster.h"

#import "XADSimpleUnarchiver.h"
#import "NSStringPrinting.h"
#import "CSCommandLineParser.h"
#import "CommandLineCommon.h"
#import "CSFileHandle.h"

NSAutoreleasePool *shared_pool = NULL;

void __attribute__ ((constructor)) my_init(void);
void __attribute__ ((destructor)) my_fini(void);

void my_init(void) {
	// entry point
}

void my_fini(void) {
	// exit point
}

#define DEF_SETTER(VARIABLE) \
void \
ArchiveSet ## VARIABLE (ArchivePrivate* a, const char * __ ## VARIABLE ##__ ) { \
	NSString *__ ## VARIABLE ## __ns = [NSString stringWithUTF8String: __## VARIABLE ##__ ]; \
	[a->unarchiver set##VARIABLE: __## VARIABLE ##__ns]; \
} \

#define DEF_SETTER_PARSER(VARIABLE) \
void \
ArchiveSet ## VARIABLE (ArchivePrivate* a, const char * __ ## VARIABLE ##__ ) { \
	NSString *__ ## VARIABLE ## __ns = [NSString stringWithUTF8String: __## VARIABLE ##__ ]; \
	[[a->unarchiver archiveParser] set##VARIABLE: __## VARIABLE ##__ns]; \
} \

#define DEF_SETTER_BOOLEAN(VARIABLE) \
void ArchiveSet ## VARIABLE (ArchivePrivate*a, int __## VARIABLE ##__) { \
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


EntryError * EntryErrorNew(EntryError e) {
	EntryError * ret = malloc(sizeof(EntryError));
	memcpy(ret, &e, sizeof(EntryError));
	if(e.error_str) {
		ret->error_str = strdup(e.error_str);
	}

	return ret;
}

void EntryErrorDestroy(EntryError * e) {
	if(e) {
		free(e->error_str);
		free(e);
	}
}

typedef struct ArchivePrivate {
	char * path;
	char * error_str;
	ArchiveError error_num;

	XADSimpleUnarchiver *unarchiver;
	NSAutoreleasePool * pool_ctx;
} ArchivePrivate;

void EntryDestroy(Entry * e) {
	free(e->filename);
	free(e->renaming);
	EntryErrorDestroy(e->error);

	free(e);
}

ArchivePrivate* ArchiveNew(const char * path) {
	ArchivePrivate* ret = (ArchivePrivate*)calloc(1, sizeof(ArchivePrivate));
	ret->pool_ctx = [NSAutoreleasePool new];
	XADError openerror;
	NSString *filename=[NSString stringWithUTF8String:path];
	ret->path = strdup(path);

	XADSimpleUnarchiver *unarchiver=[XADSimpleUnarchiver simpleUnarchiverForPath:filename error:&openerror];
	if(!unarchiver)
	{
		if(openerror)
		{
			ret->error_num = openerror;
			ret->error_str = strdup([[XADException describeXADError:openerror] UTF8String]);

			return ret;
		}

		ret->error_num = FORMAT;
		ret->error_str = strdup([@"Couldn't recognize the archive format.\n" UTF8String]);

		return ret;
	}

	ret->unarchiver = unarchiver;
	return ret;
}

void ArchiveDestroy(ArchivePrivate* a) {
	free(a->error_str);
	free(a->path);

  [a->unarchiver release];
	a->unarchiver = NULL;

	free(a);
}

// Generating output like this
// void ArchiveSetDestination(ArchivePrivate* a, const char * dest) {
// 	NSString *destination=[NSString stringWithUTF8String:dest];
// 	[a->unarchiver setDestination:destination];
// }

// Continue with macro definitions
DEF_SETTER(Destination)
DEF_SETTER(Password)

DEF_SETTER_PARSER(EncodingName)
DEF_SETTER_PARSER(PasswordEncodingName)

DEF_SETTER_BOOLEAN(AlwaysOverwritesFiles)
DEF_SETTER_BOOLEAN(AlwaysRenamesFiles)
DEF_SETTER_BOOLEAN(AlwaysSkipsFiles)
DEF_SETTER_BOOLEAN(ExtractsSubArchives)
DEF_SETTER_BOOLEAN(PropagatesRelevantMetadata)
DEF_SETTER_BOOLEAN(CopiesArchiveModificationTimeToEnclosingDirectory)
DEF_SETTER_BOOLEAN(MacResourceForkStyle)
DEF_SETTER_BOOLEAN(PerIndexRenamedFiles)

Entry ** ArchiveList(ArchivePrivate* archive) {
	NSString *path=[NSString stringWithUTF8String:archive->path];
	NULLLister *lister = [[[NULLLister alloc] init] autorelease];
	[archive->unarchiver setDelegate:lister];

	XADError parseerror=[archive->unarchiver parse];

	if(parseerror)
	{
		archive->error_num = parseerror;
		free(archive->error_str);
		archive->error_str = strdup([[XADException describeXADError:parseerror] UTF8String]);

		return NULL;
	}

	XADError unarchiveerror=[archive->unarchiver unarchive];

	if(unarchiveerror)
	{
		archive->error_num = unarchiveerror;
		free(archive->error_str);
		archive->error_str = strdup([[XADException describeXADError:unarchiveerror] UTF8String]);

		return NULL;
	}

	int numentries = [lister->entries count];
	Entry ** ret = (Entry**)calloc(numentries+1, sizeof(Entry*));

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

		entry->filename = strdup([filename UTF8String]);
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

EntryError ** getNativeErrors (NULLUnarchiver * unarchiver)
{
	int numentries = [unarchiver->xadErrors count];
	EntryError ** ret = (EntryError**)calloc(numentries+1, sizeof(EntryError*));

	for(int i=0; i < numentries; i++) {
		NSNumber * err = [unarchiver->xadErrors objectAtIndex:i];
		NSString * desc = [unarchiver->xadDescriptions objectAtIndex:i];
		NSDictionary * dict = [unarchiver->dicts objectAtIndex:i];

		EntryError * entry = calloc(1, sizeof(EntryError));

		entry->error_num = [err intValue];
		entry->error_str = strdup([desc UTF8String]);

		NSNumber *indexnum=[dict objectForKey:XADIndexKey];
		entry->eid = [indexnum intValue];

		ret[i] = entry;
	}

	return ret;
}

unsigned ArchiveExtract(ArchivePrivate* a, Entry ** ens) {
	Entry ** oens = ens;

	unsigned numentries = 0;
	NULLUnarchiver *unarchiverDelegate = [[[NULLUnarchiver alloc] init] autorelease]; // memory leak is related to NULLUnarchiver
	[a->unarchiver setDelegate:unarchiverDelegate];

	while(*ens) {
		Entry * e = *ens;

		if (e->renaming) {
			[a->unarchiver setPerIndexRenamedFiles:YES];
			//printf("Renaming id %u. %s to %s\n", e->eid, e->filename, e->renaming);
			[a->unarchiver addIndexFilter:e->eid];
			NSString *nsrename = [NSString stringWithUTF8String:e->renaming];
			[a->unarchiver addIndexRenaming:nsrename];
		}
		else {
			//printf("Not Renaming...\n");
			[a->unarchiver addIndexFilter:e->eid];
		}

		ens++;
		numentries++;
	}

	XADError unarchiveerror = [a->unarchiver unarchive];

	if(unarchiveerror)
	{
		a->error_num = unarchiveerror;
		a->error_str = strdup([[XADException describeXADError:unarchiveerror] UTF8String]);
		return 0;
	}

	// Update errors in entries
	EntryError ** ers = getNativeErrors(unarchiverDelegate);
	EntryError ** oers = ers;

	while( *ers ) {
		Entry ** entries = oens;

		while(*entries) {
			if((*entries)->eid == (*ers)->eid) {
				if((*entries)->error) {
					EntryErrorDestroy((*entries)->error);
				}

				(*entries)->error = *ers;
				break;
			}
			entries++;
		}

		if(!*entries) {
			// Not found - destroy the EntryError - this should not happen! Assert?
			EntryErrorDestroy(*ers);
		}
		ers++;
	}

	free(oers);

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
