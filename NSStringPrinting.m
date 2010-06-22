#import "NSStringPrinting.h"

#ifdef __MINGW32__
#include <windows.h>
#endif

@implementation NSString (Printing)

-(void)print
{
	[self printToFile:stdout];
}

#ifdef __MINGW32__

-(void)printToFile:(FILE *)fh
{
	int length=[self length];
	unichar buffer[length+1];
	[self getCharacters:buffer range:NSMakeRange(0,length)];
	buffer[length]=0;

	int bufsize=WideCharToMultiByte(GetConsoleOutputCP(),0,buffer,-1,NULL,0,NULL,NULL);
	char mbuffer[bufsize]; 
	WideCharToMultiByte(GetConsoleOutputCP(),0,buffer,-1,mbuffer,bufsize,NULL,NULL);

	fwrite(mbuffer,bufsize-1,1,fh);
}

#else

-(void)printToFile:(FILE *)fh
{
	int length=[self lengthOfBytesUsingEncoding:NSUTF8StringEncoding]+1;
	char buffer[length+1];
	[self getCString:buffer maxLength:length+1 encoding:NSUTF8StringEncoding];

	fwrite(buffer,length,1,fh);
}

#endif

@end
