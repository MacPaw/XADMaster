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

`gcc main.c -lXADMaster -o my`

*Notice:* - you may use other C compilers - like clang.

## Header Files
Include to your .c files this inclusion line

`#include <XADMaster.h>`.

## Example

```c
#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <XADMaster.h>

int main(int argc, char * argv[]) {
  Archive * a = ArchiveNew("/tmp/example.zip");
  ArchiveSetAlwaysOverwritesFiles(a, true);
  //

  Entry ** es = ArchiveList(a);
  Entry ** oes = es;

  int i = 0;

  while(*es) {
    char * frename = NULL;
    char
    asprintf(&frename, "binary%d.bin", i++);
    (*es)->renaming = frename;
    es++;
  }

  ArchiveExtract(a, oes);
  if(a->error_num != NO_ERROR) {
    printf("ERROR: %d ERROR MSG: %s\n", a->error_num, a->error_str );
  }

  es = oes;
  while(*es) {
    if((*es)->error) {
      printf("WARNING: (%s) %d WARNING MSG: %s\n", (*es)->filename, (*es)->error->error_num, (*es)->error->error_str);
    }

    EntryDestroy(*es);
    es++;
  }

  ArchiveDestroy(a);
  free(oes);
  return 0;
}

```

## Integration To Higher Level Languages

## Memory Issues

## C API Documentation

# License

This software is distributed under the [LGPL 2.1](https://www.gnu.org/licenses/lgpl-2.1.html) license. Please read LICENSE for information on the software availability and distribution.
