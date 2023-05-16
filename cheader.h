
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

extern Archive * ArchiveNew(const char * path, const char * password, const char * encoding);
extern Entry ** ArchiveList(Archive * archive);
unsigned ArchiveExtract(Archive * a, Entry ** entries);

#endif