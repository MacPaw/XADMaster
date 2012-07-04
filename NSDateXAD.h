#import <Foundation/Foundation.h>
#import <sys/time.h>

#ifdef __MINGW32__
#include <windows.h>
#endif

@interface NSDate (XAD)

+(NSDate *)XADDateWithTimeIntervalSince2000:(NSTimeInterval)interval;
+(NSDate *)XADDateWithTimeIntervalSince1904:(NSTimeInterval)interval;
+(NSDate *)XADDateWithTimeIntervalSince1601:(NSTimeInterval)interval;
+(NSDate *)XADDateWithMSDOSDate:(uint16_t)date time:(uint16_t)time;
+(NSDate *)XADDateWithMSDOSDate:(uint16_t)date time:(uint16_t)time timeZone:(NSTimeZone *)tz;
+(NSDate *)XADDateWithMSDOSDateTime:(uint32_t)msdos;
+(NSDate *)XADDateWithMSDOSDateTime:(uint32_t)msdos timeZone:(NSTimeZone *)tz;
+(NSDate *)XADDateWithWindowsFileTime:(uint64_t)filetime;
+(NSDate *)XADDateWithWindowsFileTimeLow:(uint32_t)low high:(uint32_t)high;
+(NSDate *)XADDateWithCPMDate:(uint16_t)date time:(uint16_t)time;

#ifndef __MINGW32__
-(struct timeval)timevalStruct;
-(struct timespec)timespecStruct;
#endif

#ifdef __APPLE__
-(UTCDateTime)UTCDateTime;
#endif

#ifdef __MINGW32__
-(FILETIME)FILETIME;
#endif

@end
