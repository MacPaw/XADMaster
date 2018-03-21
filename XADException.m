/*
 * XADException.m
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
#import "XADException.h"

#import "CSFileHandle.h"
#import "CSZlibHandle.h"
#import "CSBzip2Handle.h"

NSString *XADExceptionName=@"XADException";

@implementation XADException

+(void)raiseUnknownException  { [self raiseExceptionWithXADError:XADUnknownError]; }
+(void)raiseInputException  { [self raiseExceptionWithXADError:XADInputError]; }
+(void)raiseOutputException  { [self raiseExceptionWithXADError:XADOutputError]; }
+(void)raiseIllegalDataException  { [self raiseExceptionWithXADError:XADIllegalDataError]; }
+(void)raiseNotSupportedException  { [self raiseExceptionWithXADError:XADNotSupportedError]; }
+(void)raisePasswordException { [self raiseExceptionWithXADError:XADPasswordError]; }
+(void)raiseDecrunchException { [self raiseExceptionWithXADError:XADDecrunchError]; }
+(void)raiseChecksumException { [self raiseExceptionWithXADError:XADChecksumError]; }
+(void)raiseDataFormatException { [self raiseExceptionWithXADError:XADDataFormatError]; }
+(void)raiseOutOfMemoryException { [self raiseExceptionWithXADError:XADOutOfMemoryError]; }

+(void)raiseExceptionWithXADError:(XADError)errnum
{
//	[NSException raise:@"XADException" format:@"%@",[self describeXADError:errnum]];
	[[[[NSException alloc] initWithName:XADExceptionName reason:[self describeXADError:errnum]
	userInfo:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:errnum]
	forKey:@"XADError"]] autorelease] raise];
}



+(XADError)parseException:(id)exception
{
	if([exception isKindOfClass:[NSException class]])
	{
		NSException *e=exception;
		NSString *name=[e name];
		if([name isEqual:XADExceptionName])
		{
			return [[[e userInfo] objectForKey:@"XADError"] intValue];
		}
		else if([name isEqual:CSCannotOpenFileException]) return XADOpenFileError;
		else if([name isEqual:CSFileErrorException]) return XADUnknownError; // TODO: use ErrNo in userInfo to figure out better error
		else if([name isEqual:CSOutOfMemoryException]) return XADOutOfMemoryError;
		else if([name isEqual:CSEndOfFileException]) return XADInputError;
		else if([name isEqual:CSNotImplementedException]) return XADNotSupportedError;
		else if([name isEqual:CSNotSupportedException]) return XADNotSupportedError;
		else if([name isEqual:CSZlibException]) return XADDecrunchError;
		else if([name isEqual:CSBzip2Exception]) return XADDecrunchError;
	}

	return XADUnknownError;
}

+(NSString *)describeXADError:(XADError)error
{
	switch(error)
	{
		case XADNoError:			return nil;
		case XADUnknownError:		return @"Unknown error";
		case XADInputError:			return @"Attempted to read more data than was available";
		case XADOutputError:		return @"Failed to write to file";
		case XADBadParametersError:	return @"Function called with illegal parameters";
		case XADOutOfMemoryError:	return @"Not enough memory available";
		case XADIllegalDataError:	return @"Data is corrupted";
		case XADNotSupportedError:	return @"File is not fully supported";
		case XADResourceError:		return @"Required resource missing";
		case XADDecrunchError:		return @"Error on decrunching";
		case XADFiletypeError:		return @"Unknown file type";
		case XADOpenFileError:		return @"Opening file failed";
		case XADSkipError:			return @"File, disk has been skipped";
		case XADBreakError:			return @"User cancelled extraction";
		case XADFileExistsError:	return @"File already exists";
		case XADPasswordError:		return @"Missing or wrong password";
		case XADMakeDirectoryError:	return @"Could not create directory";
		case XADChecksumError:		return @"Wrong checksum";
		case XADVerifyError:		return @"Verify failed (disk hook)";
		case XADGeometryError:		return @"Wrong drive geometry";
		case XADDataFormatError:	return @"Unknown data format";
		case XADEmptyError:			return @"Source contains no files";
		case XADFileSystemError:	return @"Unknown filesystem";
		case XADFileDirectoryError:	return @"Name of file exists as directory";
		case XADShortBufferError:	return @"Buffer was too short";
		case XADEncodingError:		return @"Text encoding was defective";
		case XADLinkError:			return @"Could not create symlink";
		default:					return [NSString stringWithFormat:@"Error %d",error];
	}
}

@end

