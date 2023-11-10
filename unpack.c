#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <libXADMaster.h>

int main(int argc, const char **argv) {

    if (argc != 3) return PARAMETERS;

    const char *path = argv[1];
    const char *destination = argv[2];

    Archive *archive = ArchiveNew(path);

    ArchiveSetDestination(archive, destination);
    ArchiveSetAlwaysOverwritesFiles(archive, true);

    Entry **entries  = ArchiveList(archive);

    int i = 0;
    Entry **entry = entries;
    while (*entry) {
        char * renaming = malloc(sizeof(char)*513);
        snprintf(renaming, 512, "%s/%d.bin", destination, i);
        fprintf(stdout, "%d %s\n", (*entry)->dirP, (*entry)->filename);
        (*entry)->renaming = renaming;
        entry++;
        i++;
    }

    int entryCount = ArchiveExtract(archive, entries);
    if (entryCount != i) fprintf(stderr, "%d entries not extracted\n", i - entryCount);

    entry = entries;
    while (*entry) {
        if ((*entry)->error) fprintf(stderr, "%s: %s\n", (*entry)->filename, (*entry)->error->error_str);
        EntryDestroy(*entry);
        entry++;
    }

    ArchiveDestroy(archive);
    free(entries);

    return archive->error_num;

}
