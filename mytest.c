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
#include <stdbool.h>
#include "cheader.h"

int main(int argc, char * argv[]) {

  printf("HERER\n");
  /* TODO: UNAR CONTEXT CREATE/DESTROY POOL WITHIN THE LIB */
  // XADMasterEnter();
  /*

  NSAutoreleasePool *myPool = [[NSAutoreleasePool alloc] init];
  // Your code that uses autorelease...
  [myPool drain];

  */
  // TODO: GET RID OF 2 PARAMS?
  Archive * a = ArchiveNew("/tmp/neco.zip", NULL, NULL);

  // TODO: CHECK Setters like password, destination etc.
  printf("I HAVE A NEW ONE %p\n", a);
  Entry ** es = ArchiveList(a);
  Entry ** oes = es;

  while(*es) {
    printf("ES: %s\n", (*es)->filename);
    es++;
  }

  // TODO: switch

  ArchiveExtract(a, oes);

  // XADMasterLeave();

  return 0;

}

