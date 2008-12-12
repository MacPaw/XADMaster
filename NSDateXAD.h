#import <Foundation/Foundation.h>

@interface NSDate (XAD)

+(NSDate *)XADDateWithMSDOSDateTime:(unsigned long)msdos;
+(NSDate *)XADDateWithTimeIntervalSince1904:(NSTimeInterval)interval;
+(NSDate *)XADDateWithWindowsFileTimeLow:(uint32_t)low high:(uint32_t)high;

@end
