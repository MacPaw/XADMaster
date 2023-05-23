# Objective-C library for archive and file unarchiving and extraction
[![Build Status](https://travis-ci.org/MacPaw/XADMaster.svg?branch=master)](https://travis-ci.org/MacPaw/XADMaster)
* Supports multiple archive formats such as Zip, Tar, Gzip, Bzip2, 7-Zip, Rar, LhA, StuffIt, several old Amiga file and disk archives, CAB, LZX. Read [the wiki page](http://code.google.com/p/theunarchiver/wiki/SupportedFormats) for a more thorough listing of formats.
* Supports split archives for certain formats, like RAR.
* Uses [libxad](http://sourceforge.net/projects/libxad/) for older and more obscure formats. This is an old Amiga library for handling unpacking of archives.
* Depends on [UniversalDetector Library](https://github.com/MacPaw/universal-detector). Uses character set autodetection code from Mozilla to auto-detect the encoding of the filenames in the archives.
* The unarchiving engine itself is multi-platform, and command-line tools exist for Linux, Windows and other OSes.
* Originally developed by [Dag Ågren](https://github.com/DagAgren)

# Building
XADMaster relies on directories structure. To start development you'll need to clone the main project with Universal Detector library:
```
git clone https://github.com/MacPaw/XADMaster.git
git clone https://github.com/MacPaw/universal-detector.git UniversalDetector
```
The resulting directory structure should look like:

```
<development-directory>
  /XADMaster
  /UniversalDetector
```

## Unar Tool
`make -f Makefile.linux unar # For other OS change linux to your platform`

## Lsar Tool
`make -f Makefile.linux lsar # For other OS change linux to your platform`

## The Library
`make -f Makefile.linux libXADMaster.so # For Linux only now`

# Installing
`sudo make -f Makefile.linux install`

- `/usr/bin` directory is used as target for `lsar` and `unar` tool.
- `/usr/lib/libXADMaster.so` filename is used for the shared object.
- `/usr/include/XADMaster.h` is used as a C-header location.

*Notice:* `ldconfig` execution is done implicitly by running the `install` target. The `pkg-config` rule is also included - you may use `pkg-config --cflags --libs libXADMaster` later on your compilation.

# Usages
- [The Unarchiver](https://theunarchiver.com/) application.

# Library Usage
This XADMaster fork provides also programmatic API for C in form of a shared object (.so library) for Linux only at the moment.

## Linking
Following code is showing how to compile your custom C code with the library.

`gcc main.c -lXADMaster -o example.bin`

*Notice:* - you may use other C compilers - like clang.

## Header Files
Include to your .c files this inclusion line

`#include <libXADMaster.h>`.

## Example
(Taken from `example.c`).

```c
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
```

## Integration To Higher Level Languages

## Memory Issues
When testing with Valgrind tool some memory leaks are present at the exit. However no runtime memory leaks causing uncontrolled memory consumption were not detected. Further memory leaks prevention is time consuming task due to Objective-C use (OBJC garbage collector, automatized tasks in it, ...).

```sh
  LEAK SUMMARY:
    definitely lost: 8,407 bytes in 513 blocks
    indirectly lost: 7,152 bytes in 447 blocks
      possibly lost: 1,004,132 bytes in 4,595 blocks
    still reachable: 1,059,587 bytes in 12,243 blocks
                        of which reachable via heuristic:
                          newarray           : 176 bytes in 2 blocks
          suppressed: 0 bytes in 0 blocks
  Rerun with --leak-check=full to see details of leaked memory
  For lists of detected and suppressed errors, rerun with: -s
  ERROR SUMMARY: 0 errors from 0 contexts (suppressed: 12 from 4)
```

We have just `8,407` bytes definitely lost on exit, which is acceptable in this case.

## C API Documentation
The process of the documentation is in progress, however public functions are documented in the `libXADMaster.h` file as standard Doxygen doc.

# License
This software is distributed under the [LGPL 2.1](https://www.gnu.org/licenses/lgpl-2.1.html) license. Please read LICENSE for information on the software availability and distribution.
