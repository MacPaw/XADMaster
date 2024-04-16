/*
 * libXADMaster.h
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

#ifndef LIB_XADMASTER_H
#define LIB_XADMASTER_H

#include <string.h>

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


/** Structure describing error on an entry during processing. */
typedef struct EntryError {
	/** Numerical representation of error. */
	ArchiveError error_num;
	/** Stringual representation of error. */
	char * error_str;
	/** Entry identifier. */
	int eid;
} EntryError;


/** Structure representing an archive entry (record). */
typedef struct Entry {
	/** Full path with filename within the archive. */
	char *filename;
	/** Predicate - is directory? */
	int dirP;
	/** Predicate - is link? */
	int linkP;
	/** Predicate - is a resource? */
	int resourceP;
	/** Predicate - is corrupted? */
	int corruptedP;
	/** Predicate - is encrypted by using of password? */
	int encryptedP;
	/** Entry unique identifier. */
	unsigned long eid;
	/** Entry detected encoding. */
	const char * encoding;
	/** Entry renaming - you may set entry destination by hand by setting this. This field gets freed at EntryDestroy(). */
	char * renaming;
	/** Error record. */
	EntryError * error;
	/** Unpacked size. */
	unsigned size;
} Entry;

/** Sets renaming for the entry from constant string and allocates copy.
 * \param self An Entry pointer.
 * \param renaming A constant string.
*/
inline void EntrySetRenaming(Entry * self, const char * renaming) {
	self->renaming = strdup(renaming);
}

#ifndef __LIBXAD_PRIVATE_PART

/** Structure representing an archive - archive files like .zips, .rar, .tar and other supported archives. */
typedef struct Archive {
	/** Path to the archive file. */
	char * path;
	/** Last error on archive. */
	char * error_str;
	/** Last archive error code. */
	ArchiveError error_num;
} Archive;

/** Destroy an Entry. All pointer-type fields get freed. */
extern void EntryDestroy(Entry * e);

/** Allocates new archive and perform general checks (file-existence, basic consistency check, ...).
 * \param path Path to the archive.
 *
 * \return A valid Archive instance. If error appears errors are set within the error_num and error_str fields.
*/

Archive * ArchiveNew(const char * path);

/** Destroy an Archive and frees all pointers in it.
 * \param a A valid Archive pointer.
*/
void ArchiveDestroy(Archive * a);

/** Lists content of an archive in form of NULL-terminated arrays.
 *
 * \param archive Archive pointer.
 *
 * \returns A newly allocated NULL-terminated array of Entries. The array must be freed manually at the end. Entry records must be destroyed by EntryDestroy() call explicitly.
*/
Entry ** ArchiveList(Archive * archive);

/** Extracts an archive by passing an NULL-terminated Entry array.
 *
 * \param a Archive pointer.
 * \param entries NULL-terminated array of Entries.
 *
 * \returns Number of successfully extracted Entries. Sets error on entries if any (side-effect).
 */
unsigned ArchiveExtract(Archive * a, Entry ** entries);

#define DEF_SETTER_PROTO(VARIABLE) \
void ArchiveSet ## VARIABLE (Archive * a, const char * __ ## VARIABLE ##__ ); \

#define DEF_SETTER_BOOLEAN_PROTO(VARIABLE) \
void ArchiveSet ## VARIABLE (Archive *a, int __## VARIABLE ##__); \

/*! \fn void ArchiveSetDestination(Archive * a, const char * Destination)
    \brief Sets default destination for entries at extraction.
    \param a Archive pointer.
		\param Destination The destination path.
*/

/*! \fn void ArchiveSetPassword(Archive * a, const char * Password)
    \brief Sets default password for entries at extraction.
    \param a Archive pointer.
		\param Password The password.
*/

/*! \fn void ArchiveSetEncodingName(Archive * a, const char * EncodingName)
    \brief Sets default encoding name for entries at extraction.
    \param a Archive pointer.
		\param EncodingName The encoding name.
*/

/*! \fn void ArchiveSetPasswordEncodingName(Archive * a, const char * PasswordEncodingName)
    \brief Sets default password encoding name for entries at extraction.
    \param a Archive pointer.
		\param PasswordEncodingName The password encoding name.
*/

DEF_SETTER_PROTO(Destination)
DEF_SETTER_PROTO(Password)
DEF_SETTER_PROTO(EncodingName)
DEF_SETTER_PROTO(PasswordEncodingName)

/*! \fn void ArchiveSetAlwaysOverwriteFile(Archive * a, int AlwaysOverwriteFiles)
    \brief Sets if always overwrite files if they are present on the destination path.
    \param a Archive pointer.
		\param AlwaysOverwriteFiles Set to 0 if no, set something else if yes.
*/
DEF_SETTER_BOOLEAN_PROTO(AlwaysOverwritesFiles)

/*! \fn void ArchiveSetAlwaysRenamesFiles(Archive * a, int AlwaysRenamesFiles)
    \brief Sets if always rename files if they are present on the destination path. Note that this is unusable now - no way how to interactively rename.
    \param a Archive pointer.
		\param AlwaysRenamesFiles Set to 0 if no, set something else if yes.
*/
DEF_SETTER_BOOLEAN_PROTO(AlwaysRenamesFiles)

/*! \fn void ArchiveSetAlwaysSkipsFiles(Archive * a, int AlwaysSkipsFiles)
    \brief Sets if always skip files on error.
    \param a Archive pointer.
		\param AlwaysSkipsFiles Set to 0 if no, set something else if yes.
*/
DEF_SETTER_BOOLEAN_PROTO(AlwaysSkipsFiles)

/*! \fn void ArchiveSetExtractsSubArchives(Archive * a, int ExtractsSubArchives)
    \brief Sets if extract also included subarchives. Not recommended set to yes - unsufficient testing.
    \param a Archive pointer.
		\param ExtractsSubArchives Set to 0 if no, set something else if yes.
*/
DEF_SETTER_BOOLEAN_PROTO(ExtractsSubArchives)

/*! \fn void ArchiveSetPropagatesRelevantMetadata(Archive * a, int PropagatesRelevantMetadata)
    \brief Sets if propagate relevant metadata (passwords etc.). Not recommended set to yes - unsufficient testing.
    \param a Archive pointer.
		\param PropagatesRelevantMetadata Set to 0 if no, set something else if yes.
*/
DEF_SETTER_BOOLEAN_PROTO(PropagatesRelevantMetadata)


/*! \fn void ArchiveSetCopiesArchiveModificationTimeToEnclosingDirectory(Archive * a, int CopiesArchiveModificationTimeToEnclosingDirectory)
    \brief Sets if to set entries' modification time also to the destination files.
    \param a Archive pointer.
		\param CopiesArchiveModificationTimeToEnclosingDirectory Set to 0 if no, set something else if yes.
*/
DEF_SETTER_BOOLEAN_PROTO(CopiesArchiveModificationTimeToEnclosingDirectory)

/*! \fn void ArchiveSetMacResourceForkStyle(Archive * a, int MacResourceForkStyle)
    \brief Sets if to use MacOS forking style. Not recommended - not tested on Linux, just for completeness.
    \param a Archive pointer.
		\param MacResourceForkStyle Set to 0 if no, set something else if yes.
*/
DEF_SETTER_BOOLEAN_PROTO(MacResourceForkStyle)

/*! \fn void ArchiveSetPerIndexRenamedFiles(Archive * a, int PerIndexRenamedFiles)
    \brief Sets if to use entry renaming. This is automatically driven by the glue. Do not use it.
    \param a Archive pointer.
		\param PerIndexRenamedFiles Set to 0 if no, set something else if yes.
*/
DEF_SETTER_BOOLEAN_PROTO(PerIndexRenamedFiles)

#endif

#endif