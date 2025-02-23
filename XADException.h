/*
 * XADException.h
 *
 * Copyright (c) 2017-present, MacPaw Inc. All rights reserved.
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
#import <Foundation/Foundation.h>

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wquoted-include-in-framework-header"
#import "XADTypes.h"
#import "ClangAnalyser.h"
#pragma clang diagnostic pop

XADEXTERN NSErrorDomain const XADErrorDomain;

#if ((__cplusplus && __cplusplus >= 201103L && (__has_extension(cxx_strong_enums) || __has_feature(objc_fixed_enum))) || (!__cplusplus && __has_feature(objc_fixed_enum))) && __has_attribute(ns_error_domain)
#define XAD_ERROR_ENUM(_domain, _name)     enum _name : int _name; enum __attribute__((ns_error_domain(_domain))) _name : int
#else
#define XAD_ERROR_ENUM(_domain, _name) NS_ENUM(int, _name)
#endif

typedef XAD_ERROR_ENUM(XADErrorDomain, XADError) {
	XADErrorNone =			0x0000, /*!< no error */
	XADErrorUnknown =		0x0001, /*!< unknown error */
	XADErrorInput =			0x0002, /*!< input data buffers border exceeded */
	XADErrorOutput =		0x0003, /*!< failed to write to file */
	XADErrorBadParameters =	0x0004, /*!< function called with illegal parameters */
	XADErrorOutOfMemory =	0x0005, /*!< not enough memory available */
	XADErrorIllegalData =	0x0006, /*!< data is corrupted */
	XADErrorNotSupported =	0x0007, /*!< file not fully supported */
	XADErrorResource =		0x0008, /*!< required resource missing */
	XADErrorDecrunch =		0x0009, /*!< error on decrunching */
	XADErrorFiletype =		0x000A, /*!< unknown file type */
	XADErrorOpenFile =		0x000B, /*!< opening file failed */
	XADErrorSkip =			0x000C, /*!< file, disk has been skipped */
	XADErrorBreak =			0x000D, /*!< user break in progress hook */
	XADErrorFileExists =	0x000E, /*!< file already exists */
	XADErrorPassword =		0x000F, /*!< missing or wrong password */
	XADErrorMakeDirectory =	0x0010, /*!< could not create directory */
	XADErrorChecksum =		0x0011, /*!< wrong checksum */
	XADErrorVerify =		0x0012, /*!< verify failed (disk hook) */
	XADErrorGeometry =		0x0013, /*!< wrong drive geometry */
	XADErrorDataFormat =	0x0014, /*!< unknown data format */
	XADErrorEmpty =			0x0015, /*!< source contains no files */
	XADErrorFileSystem =	0x0016, /*!< unknown filesystem */
	XADErrorFileDirectory =	0x0017, /*!< name of file exists as directory */
	XADErrorShortBuffer =	0x0018, /*!< buffer was too short */
	XADErrorEncoding =		0x0019, /*!< text encoding was defective */
	XADErrorLink =			0x001a, /*!< could not create link */

	XADErrorSubArchive = 0x10000
};

XADEXTERN NSExceptionName const XADExceptionName;
XADEXTERN NSErrorUserInfoKey const XADExceptionReasonKey;

XADEXPORT
@interface XADException:NSObject
{
}

+(void)raiseUnknownException CLANG_ANALYZER_NORETURN;
+(void)raiseInputException CLANG_ANALYZER_NORETURN;
+(void)raiseOutputException CLANG_ANALYZER_NORETURN;
+(void)raiseIllegalDataException CLANG_ANALYZER_NORETURN;
+(void)raiseNotSupportedException CLANG_ANALYZER_NORETURN;
+(void)raiseDecrunchException CLANG_ANALYZER_NORETURN;
+(void)raisePasswordException CLANG_ANALYZER_NORETURN;
+(void)raiseChecksumException CLANG_ANALYZER_NORETURN;
+(void)raiseDataFormatException CLANG_ANALYZER_NORETURN;
+(void)raiseOutOfMemoryException CLANG_ANALYZER_NORETURN;
+(void)raiseExceptionWithXADError:(XADError)errnum CLANG_ANALYZER_NORETURN;
+(void)raiseExceptionWithXADError:(XADError)errnum underlyingError:(NSError*)nsErr CLANG_ANALYZER_NORETURN;

+(XADError)parseException:(id)exception;
+(NSError*)parseExceptionReturningNSError:(id)exception;
+(NSString *)describeXADError:(XADError)errnum;

@end

static const XADError XADNoError API_DEPRECATED_WITH_REPLACEMENT("XADErrorNone", macosx(10.0, 10.8), ios(3.0, 8.0)) = XADErrorNone;
static const XADError XADUnknownError API_DEPRECATED_WITH_REPLACEMENT("XADErrorUnknown", macosx(10.0, 10.8), ios(3.0, 8.0)) = XADErrorUnknown;
static const XADError XADInputError API_DEPRECATED_WITH_REPLACEMENT("XADErrorInput", macosx(10.0, 10.8), ios(3.0, 8.0)) = XADErrorInput;
static const XADError XADOutputError API_DEPRECATED_WITH_REPLACEMENT("XADErrorOutput", macosx(10.0, 10.8), ios(3.0, 8.0)) = XADErrorOutput;
static const XADError XADBadParametersError API_DEPRECATED_WITH_REPLACEMENT("XADErrorBadParameters", macosx(10.0, 10.8), ios(3.0, 8.0)) = XADErrorBadParameters;
static const XADError XADOutOfMemoryError API_DEPRECATED_WITH_REPLACEMENT("XADErrorOutOfMemory", macosx(10.0, 10.8), ios(3.0, 8.0)) = XADErrorOutOfMemory;
static const XADError XADIllegalDataError API_DEPRECATED_WITH_REPLACEMENT("XADErrorIllegalData", macosx(10.0, 10.8), ios(3.0, 8.0)) = XADErrorIllegalData;
static const XADError XADNotSupportedError API_DEPRECATED_WITH_REPLACEMENT("XADErrorNotSupported", macosx(10.0, 10.8), ios(3.0, 8.0)) = XADErrorNotSupported;
static const XADError XADResourceError API_DEPRECATED_WITH_REPLACEMENT("XADErrorResource", macosx(10.0, 10.8), ios(3.0, 8.0)) = XADErrorResource;
static const XADError XADDecrunchError API_DEPRECATED_WITH_REPLACEMENT("XADErrorDecrunch", macosx(10.0, 10.8), ios(3.0, 8.0)) = XADErrorDecrunch;
static const XADError XADFiletypeError API_DEPRECATED_WITH_REPLACEMENT("XADErrorFiletype", macosx(10.0, 10.8), ios(3.0, 8.0)) = XADErrorFiletype;
static const XADError XADOpenFileError API_DEPRECATED_WITH_REPLACEMENT("XADErrorOpenFile", macosx(10.0, 10.8), ios(3.0, 8.0)) = XADErrorOpenFile;
static const XADError XADSkipError API_DEPRECATED_WITH_REPLACEMENT("XADErrorSkip", macosx(10.0, 10.8), ios(3.0, 8.0)) = XADErrorSkip;
static const XADError XADBreakError API_DEPRECATED_WITH_REPLACEMENT("XADErrorBreak", macosx(10.0, 10.8), ios(3.0, 8.0)) = XADErrorBreak;
static const XADError XADFileExistsError API_DEPRECATED_WITH_REPLACEMENT("XADErrorFileExists", macosx(10.0, 10.8), ios(3.0, 8.0)) = XADErrorFileExists;
static const XADError XADPasswordError API_DEPRECATED_WITH_REPLACEMENT("XADErrorPassword", macosx(10.0, 10.8), ios(3.0, 8.0)) = XADErrorPassword;
static const XADError XADMakeDirectoryError API_DEPRECATED_WITH_REPLACEMENT("XADErrorMakeDirectory", macosx(10.0, 10.8), ios(3.0, 8.0)) = XADErrorMakeDirectory;
static const XADError XADChecksumError API_DEPRECATED_WITH_REPLACEMENT("XADErrorChecksum", macosx(10.0, 10.8), ios(3.0, 8.0)) = XADErrorChecksum;
static const XADError XADVerifyError API_DEPRECATED_WITH_REPLACEMENT("XADErrorVerify", macosx(10.0, 10.8), ios(3.0, 8.0)) = XADErrorVerify;
static const XADError XADGeometryError API_DEPRECATED_WITH_REPLACEMENT("XADErrorGeometry", macosx(10.0, 10.8), ios(3.0, 8.0)) = XADErrorGeometry;
static const XADError XADDataFormatError API_DEPRECATED_WITH_REPLACEMENT("XADErrorDataFormat", macosx(10.0, 10.8), ios(3.0, 8.0)) = XADErrorDataFormat;
static const XADError XADEmptyError API_DEPRECATED_WITH_REPLACEMENT("XADErrorEmpty", macosx(10.0, 10.8), ios(3.0, 8.0)) = XADErrorEmpty;
static const XADError XADFileSystemError API_DEPRECATED_WITH_REPLACEMENT("XADErrorFileSystem", macosx(10.0, 10.8), ios(3.0, 8.0)) = XADErrorFileSystem;
static const XADError XADFileDirectoryError API_DEPRECATED_WITH_REPLACEMENT("XADErrorFileDirectory", macosx(10.0, 10.8), ios(3.0, 8.0)) = XADErrorFileDirectory;
static const XADError XADShortBufferError API_DEPRECATED_WITH_REPLACEMENT("XADErrorShortBuffer", macosx(10.0, 10.8), ios(3.0, 8.0)) = XADErrorShortBuffer;
static const XADError XADEncodingError API_DEPRECATED_WITH_REPLACEMENT("XADErrorEncoding", macosx(10.0, 10.8), ios(3.0, 8.0)) = XADErrorEncoding;
static const XADError XADLinkError API_DEPRECATED_WITH_REPLACEMENT("XADErrorLink", macosx(10.0, 10.8), ios(3.0, 8.0)) = XADErrorLink;

static const XADError XADSubArchiveError API_DEPRECATED_WITH_REPLACEMENT("XADErrorSubArchive", macosx(10.0, 10.8), ios(3.0, 8.0)) = XADErrorSubArchive;
