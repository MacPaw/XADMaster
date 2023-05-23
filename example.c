/**
 * Copyright (C) 2023 SpongeData s.r.o.
 *
 * NativeExtractor is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * NativeExtractor is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with NativeExtractor. If not, see <http://www.gnu.org/licenses/>.
 */

#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include "libXADMaster.h"

int main(int argc, char * argv[]) {
  Archive * a = ArchiveNew("/tmp/default.zip");

  // Destination setting is important for not renamed
  // entries only. Otherwise ignored.
  ArchiveSetDestination(a, "/tmp/somewhere");

  // Programmer may call glued archive methods here
  ArchiveSetAlwaysOverwritesFiles(a, true);

  // Make NULL-terminated list of Entries
  Entry ** es = ArchiveList(a);
  Entry ** oes = es;
  int i = 0;

  // Optional entries rename
  while(*es) {
    // See to the error ispection at the bottom.
    // Freeing is done there via EntryDestroy method.
    char * frename = malloc(sizeof(char)*513);
    // Renaming field contains full path to the resulting file.
    snprintf(frename, 512, "binary%d.bin", i++);
    (*es)->renaming = frename;
    printf("MARKING ID: (%lu) WITH ORIGINAL NAME: (%s) TO EXTRACT AS: (%s)\n", (*es)->eid, (*es)->filename, (*es)->renaming);
    es++;
  }

  // Does extraction over the list of Entries
  // Note that you may pass just a subset of the original list
  ArchiveExtract(a, oes);

  // Error Checking based on comparison of predefined errors
  // ArchiveError enum.
  if(a->error_num != NO_ERROR) {
    printf("ERROR: %d ERROR MSG: %s\n", a->error_num, a->error_str);
  }

  es = oes;
  while(*es) {
    // Inspection of per-Entry errors. Errors get set via
    // the entry's error field (EntryError struct).
    if((*es)->error) {
      printf("WARNING: (%s) %d WARNING MSG: %s\n", (*es)->filename, (*es)->error->error_num, (*es)->error->error_str);
    }

    // Correct Entry removal - note that renaming field *MUST*
    // be freeable.
    EntryDestroy(*es);
    es++;
  }

  // Correct Archive record deletion.
  ArchiveDestroy(a);

  // Finally free the NULL-terminated array.
  free(oes);
  return 0;
}
