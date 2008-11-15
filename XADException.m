#import "XADException.h"


@implementation XADException

+(void)raiseUnknownException  { [self raiseExceptionWithXADError:XADUnknownError]; }
+(void)raiseIllegalDataException  { [self raiseExceptionWithXADError:XADIllegalDataError]; }
+(void)raiseNotSupportedException  { [self raiseExceptionWithXADError:XADNotSupportedError]; }
+(void)raisePasswordException { [self raiseExceptionWithXADError:XADPasswordError]; }
+(void)raiseDecrunchException { [self raiseExceptionWithXADError:XADDecrunchError]; }
+(void)raiseChecksumError { [self raiseExceptionWithXADError:XADChecksumError]; }
+(void)raiseDataFormatException { [self raiseExceptionWithXADError:XADDataFormatError]; }

+(void)raiseExceptionWithXADError:(XADError)errnum
{
	[NSException raise:@"XADException" format:@"%d",errnum];
}

@end
