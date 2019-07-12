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

# Usages

- [The Unarchiver](https://theunarchiver.com/) application.


# License

This software is distributed under the [LGPL 2.1](https://www.gnu.org/licenses/lgpl-2.1.html) license. Please read LICENSE for information on the software availability and distribution.
