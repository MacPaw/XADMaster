#import "NSDateXAD.h"

@implementation NSDate (XAD)

+(NSDate *)XADDateWithTimeIntervalSince1904:(NSTimeInterval)interval
{
	return [NSDate dateWithTimeIntervalSince1970:interval-2082844800
	-[[NSTimeZone defaultTimeZone] secondsFromGMT]];
}

+(NSDate *)XADDateWithTimeIntervalSince1601:(NSTimeInterval)interval
{
	return [NSDate dateWithTimeIntervalSince1970:interval-11644473600];
}

+(NSDate *)XADDateWithMSDOSDate:(uint16_t)date time:(uint16_t)time
{
	return [self XADDateWithMSDOSDateTime:((uint32_t)date<<16)|(uint32_t)time];
}

+(NSDate *)XADDateWithMSDOSDateTime:(uint32_t)msdos
{
	int second=(msdos&31)*2;
	int minute=(msdos>>5)&63;
	int hour=(msdos>>11)&31;
	int day=(msdos>>16)&31;
	int month=(msdos>>21)&15;
	int year=1980+(msdos>>25);
	return [NSCalendarDate dateWithYear:year month:month day:day hour:hour minute:minute second:second timeZone:nil];
}

+(NSDate *)XADDateWithWindowsFileTime:(uint64_t)filetime
{
	return [NSDate XADDateWithTimeIntervalSince1601:(double)filetime/10000000];
}

+(NSDate *)XADDateWithWindowsFileTimeLow:(uint32_t)low high:(uint32_t)high
{
	return [NSDate XADDateWithWindowsFileTime:((uint64_t)high<<32)|(uint64_t)low];
}

-(struct timeval)timevalStruct
{
	NSTimeInterval seconds=[self timeIntervalSince1970];
	struct timeval tv={ (time_t)seconds, (suseconds_t)(fmod(seconds,1.0)*1000000) };
	return tv;
}

#ifdef __APPLE__
static NSDate *dateForJan1904()
{
	static NSDate *jan1904=nil;
	if(!jan1904) jan1904=[[NSDate dateWithString:@"1904-01-01 00:00:00 +0000"] retain];
	return jan1904;
}

-(UTCDateTime)UTCDateTime
{
	NSTimeInterval seconds=[self timeIntervalSinceDate:dateForJan1904()];
	UTCDateTime utc={
		(UInt16)(seconds/4294967296.0),
		(UInt32)seconds,
		(UInt16)(seconds*65536.0)
	};
	return utc;
}
#endif

@end
