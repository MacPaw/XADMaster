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

NSString *const XADExceptionName=@"XADException";
NSString *const XADErrorDomain=@"de.dstoecker.xadmaster.error";
NSString *const XADExceptionReasonKey=@"XADExceptionReason";

@implementation XADException

+(void)raiseUnknownException  { [self raiseExceptionWithXADError:XADErrorUnknown]; }
+(void)raiseInputException  { [self raiseExceptionWithXADError:XADErrorInput]; }
+(void)raiseOutputException  { [self raiseExceptionWithXADError:XADErrorOutput]; }
+(void)raiseIllegalDataException  { [self raiseExceptionWithXADError:XADErrorIllegalData]; }
+(void)raiseNotSupportedException  { [self raiseExceptionWithXADError:XADErrorNotSupported]; }
+(void)raisePasswordException { [self raiseExceptionWithXADError:XADErrorPassword]; }
+(void)raiseDecrunchException { [self raiseExceptionWithXADError:XADErrorDecrunch]; }
+(void)raiseChecksumException { [self raiseExceptionWithXADError:XADErrorChecksum]; }
+(void)raiseDataFormatException { [self raiseExceptionWithXADError:XADErrorDataFormat]; }
+(void)raiseOutOfMemoryException { [self raiseExceptionWithXADError:XADErrorOutOfMemory]; }

+(void)raiseExceptionWithXADError:(XADError)errnum
{
//	[NSException raise:@"XADException" format:@"%@",[self describeXADError:errnum]];
	[[[[NSException alloc] initWithName:XADExceptionName reason:[self describeXADError:errnum]
	userInfo:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:errnum]
	forKey:@"XADError"]] autorelease] raise];
}

+(void)raiseExceptionWithXADError:(XADError)errnum underlyingError:(NSError*)nsErr
{
	[[[[NSException alloc] initWithName:XADExceptionName reason:[self describeXADError:errnum]
							   userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:errnum], @"XADError", nsErr, NSUnderlyingErrorKey, nil]] autorelease] raise];
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
		else if([name isEqual:CSCannotOpenFileException]) return XADErrorOpenFile;
		else if([name isEqual:CSFileErrorException]) return XADErrorUnknown; // TODO: use ErrNo in userInfo to figure out better error
		else if([name isEqual:CSOutOfMemoryException]) return XADErrorOutOfMemory;
		else if([name isEqual:CSEndOfFileException]) return XADErrorInput;
		else if([name isEqual:CSNotImplementedException]) return XADErrorNotSupported;
		else if([name isEqual:CSNotSupportedException]) return XADErrorNotSupported;
		else if([name isEqual:CSZlibException]) return XADErrorDecrunch;
		else if([name isEqual:CSBzip2Exception]) return XADErrorDecrunch;
	}

	return XADErrorUnknown;
}

+(NSError*)parseExceptionReturningNSError:(id)exception
{
	if([exception isKindOfClass:[NSException class]])
	{
		NSException *e=exception;
		NSString *name=[e name];
		NSMutableDictionary *usrInfo = [NSMutableDictionary dictionaryWithDictionary:e.userInfo ?: [NSDictionary dictionary]];
		[usrInfo setValue:e.reason forKey:XADExceptionReasonKey];
		if ([name isEqualToString:XADExceptionName]) {
			XADError errVal = [[[e userInfo] objectForKey:@"XADError"] intValue];
			return [NSError errorWithDomain:XADErrorDomain code:errVal userInfo:usrInfo];
		} else if([name isEqualToString:CSCannotOpenFileException]) {
			return [NSError errorWithDomain:XADErrorDomain code:XADErrorOpenFile userInfo:usrInfo];
		} else if([name isEqualToString:CSFileErrorException]) {
			if (usrInfo && [usrInfo objectForKey:@"ErrNo"]) {
				int errNo = [[usrInfo objectForKey:@"ErrNo"] intValue];
				[usrInfo removeObjectForKey:@"ErrNo"];
				return [NSError errorWithDomain:NSPOSIXErrorDomain code:errNo userInfo:usrInfo];
			}
			return [NSError errorWithDomain:XADErrorDomain code:XADErrorUnknown userInfo:usrInfo];
		} else if([name isEqualToString:CSOutOfMemoryException]) {
			return [NSError errorWithDomain:XADErrorDomain code:XADErrorOutOfMemory userInfo:usrInfo];
		} else if([name isEqualToString:CSEndOfFileException]) {
			return [NSError errorWithDomain:XADErrorDomain code:XADErrorInput userInfo:usrInfo];
		} else if([name isEqualToString:CSNotImplementedException]) {
			return [NSError errorWithDomain:XADErrorDomain code:XADErrorNotSupported userInfo:usrInfo];
		} else if([name isEqualToString:CSNotSupportedException]) {
			return [NSError errorWithDomain:XADErrorDomain code:XADErrorNotSupported userInfo:usrInfo];
		} else if([name isEqualToString:CSZlibException]) {
			return [NSError errorWithDomain:XADErrorDomain code:XADErrorDecrunch userInfo:usrInfo];
		} else if([name isEqualToString:CSBzip2Exception]) {
			return [NSError errorWithDomain:XADErrorDomain code:XADErrorDecrunch userInfo:usrInfo];
		} else {
			return [NSError errorWithDomain:XADErrorDomain code:XADErrorUnknown userInfo:usrInfo];
		}
	}
	
	return [NSError errorWithDomain:XADErrorDomain code:XADErrorUnknown userInfo:nil];
}

+(NSString *)describeXADError:(XADError)error
{
	switch(error)
	{
		case XADErrorNone:			return nil;
		case XADErrorUnknown:		return @"Unknown error";
		case XADErrorInput:			return @"Attempted to read more data than was available";
		case XADErrorOutput:		return @"Failed to write to file";
		case XADErrorBadParameters:	return @"Function called with illegal parameters";
		case XADErrorOutOfMemory:	return @"Not enough memory available";
		case XADErrorIllegalData:	return @"Data is corrupted";
		case XADErrorNotSupported:	return @"File is not fully supported";
		case XADErrorResource:		return @"Required resource missing";
		case XADErrorDecrunch:		return @"Error on decrunching";
		case XADErrorFiletype:		return @"Unknown file type";
		case XADErrorOpenFile:		return @"Opening file failed";
		case XADErrorSkip:			return @"File, disk has been skipped";
		case XADErrorBreak:			return @"User cancelled extraction";
		case XADErrorFileExists:	return @"File already exists";
		case XADErrorPassword:		return @"Missing or wrong password";
		case XADErrorMakeDirectory:	return @"Could not create directory";
		case XADErrorChecksum:		return @"Wrong checksum";
		case XADErrorVerify:		return @"Verify failed (disk hook)";
		case XADErrorGeometry:		return @"Wrong drive geometry";
		case XADErrorDataFormat:	return @"Unknown data format";
		case XADErrorEmpty:			return @"Source contains no files";
		case XADErrorFileSystem:	return @"Unknown filesystem";
		case XADErrorFileDirectory:	return @"Name of file exists as directory";
		case XADErrorShortBuffer:	return @"Buffer was too short";
		case XADErrorEncoding:		return @"Text encoding was defective";
		case XADErrorLink:			return @"Could not create symlink";
		default:					return [NSString stringWithFormat:@"Error %d",error];
	}
}

@end

