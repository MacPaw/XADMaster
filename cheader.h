
#ifndef CHEADER_H
#define CHEADER_H

typedef enum ArchiveError {
	NO_ERROR = 0,
	UNKNOWN,
	INPUT,
	OUTPUT,
	PARAMETERS,
	OUT_OF_MEMORY,
	ILLEGAL_DATA,
	NOT_SUPPORTED,
	RESOURCE,
	DECRUNCH,
	FILETYPE,
	OPEN_FILE,
	SKIP,
	BREAK,
	FILE_EXISTS,
	PASSWORD,
	DIRECTORY_CREAT,
	CHECKSUM,
	VERIFY,
	GEOMETRY,
	FORMAT,
	EMPTY,
	FILESYSTEM,
	DIRECTORY,
	SHORT_BUFFER,
	ENCODING,
	LINK,

	ENTRY_WRONG_PASSWORD,
	ENTRY_NOT_SUPPORTED,
	ENTRY_UNPACKING_ERROR,
	ENTRY_WRONG_SIZE,
	ENTRY_HAS_NO_CHECKSUM,
	ENTRY_CHECKSUM_INCORRECT,

	SUBARCHIVE = 0x10000,

	OTHER = 255
} ArchiveError;

typedef struct Archive {
	char * path;

	char * error_str;
	ArchiveError error_num;

	//XADSimpleUnarchiver *unarchiver; hide for public purposes
} Archive;

typedef struct EntryError {
	ArchiveError error_num;
	char * error_str;
	int eid;
} EntryError;

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

	EntryError * error;

	unsigned size;
} Entry;

void EntryDestroy(Entry * e);

Archive * ArchiveNew(const char * path);
void ArchiveDestroy(Archive * a);

Entry ** ArchiveList(Archive * archive);
unsigned ArchiveExtract(Archive * a, Entry ** entries);

#define DEF_SETTER_PROTO(VARIABLE) \
void ArchiveSet ## VARIABLE (Archive * a, const char * __ ## VARIABLE ##__ ); \

#define DEF_SETTER_BOOLEAN_PROTO(VARIABLE) \
void ArchiveSet ## VARIABLE (Archive *a, int __## VARIABLE ##__); \

DEF_SETTER_PROTO(Destination)
DEF_SETTER_PROTO(Password)
DEF_SETTER_PROTO(EncodingName)
DEF_SETTER_PROTO(PasswordEncodingName)

DEF_SETTER_BOOLEAN_PROTO(AlwaysOverwritesFiles)
DEF_SETTER_BOOLEAN_PROTO(AlwaysRenamesFiles)
DEF_SETTER_BOOLEAN_PROTO(AlwaysSkipsFiles)
DEF_SETTER_BOOLEAN_PROTO(ExtractsSubArchives)
DEF_SETTER_BOOLEAN_PROTO(PropagatesRelevantMetadata)
DEF_SETTER_BOOLEAN_PROTO(CopiesArchiveModificationTimeToEnclosingDirectory)
DEF_SETTER_BOOLEAN_PROTO(MacResourceForkStyle)
DEF_SETTER_BOOLEAN_PROTO(PerIndexRenamedFiles)

#endif