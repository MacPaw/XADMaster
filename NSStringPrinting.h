#import <Foundation/Foundation.h>

@interface NSString (Printing)

+(int)terminalWidth;

-(void)print;
-(void)printToFile:(FILE *)fh;

-(NSArray *)linesWrappedToWidth:(int)width;

@end
