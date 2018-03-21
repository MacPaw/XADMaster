/*
 * NSDateXAD.h
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
#import <sys/time.h>

#ifdef __MINGW32__
#include <windows.h>
#endif

@interface NSDate (XAD)

+(NSDate *)XADDateWithYear:(int)year month:(int)month day:(int)day
hour:(int)hour minute:(int)minute second:(int)second timeZone:(NSTimeZone *)timezone;
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
#ifdef __UTCUTILS__
-(UTCDateTime)UTCDateTime;
#endif
#endif

#ifdef __MINGW32__
-(FILETIME)FILETIME;
#endif

@end
