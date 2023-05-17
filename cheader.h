
#ifndef CHEADER_H
#define CHEADER_H

typedef struct Archive {
	const char * path;
	const char * password;
	const char * encoding;
	char * lastError;

	//XADSimpleUnarchiver *unarchiver; hide for public purposes
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

extern Archive * ArchiveNew(const char * path);
extern Entry ** ArchiveList(Archive * archive);
unsigned ArchiveExtract(Archive * a, Entry ** entries);
void ArchiveDestroy(Archive * a);

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