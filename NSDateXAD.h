#import <Foundation/Foundation.h>

@interface NSDate (XAD)

+(NSDate *)XADDateWithMSDOSDateTime:(unsigned long)msdos;
+(NSDate *)XADDateWithTimeIntervalSince1904:(NSTimeInterval)interval;

@end
