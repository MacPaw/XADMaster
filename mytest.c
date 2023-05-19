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
#include "cheader.h"

int main(int argc, char * argv[]) {
  // TODO: GET RID OF 2 PARAMS?

  // Memory leak detected for password-containing records! 270kB in this case for each instance!
  Archive * a = ArchiveNew("/tmp/pass.zip");

  ArchiveSetDestination(a, "/tmp/neco/"); /* works just for not renamed! */
  ArchiveSetAlwaysOverwritesFiles(a, true);

  // TODO: CHECK Setters like password, destination etc.
  printf("I HAVE A NEW ONE %p\n", a);
  Entry ** es = ArchiveList(a);
  Entry ** oes = es;

  int i = 0;

  while(*es) {
    char * frename = NULL;
    asprintf(&frename, "binary%d.bin", i++);
    printf("ES: %s\n", (*es)->filename);
    (*es)->renaming = frename;
    es++;
  }

  ArchiveExtract(a, oes); /* TODO: errors/warnings - memory leakage here */

  printf("%d %s\n", a->error_num, a->error_str );

  es = oes;
  while(*es) {
    if((*es)->error) {
      printf("(%s) %d %s\n", (*es)->filename, (*es)->error->error_num, (*es)->error->error_str);
    }

    EntryDestroy(*es);
    es++;
  }

  ArchiveDestroy(a);

  free(oes);
  return 0;
}

