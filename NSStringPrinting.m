#import "NSStringPrinting.h"

#ifdef __MINGW32__
#include <windows.h>
#endif

@implementation NSString (Printing)

-(void)print
{
	[self printToFile:stdout];
}

-(NSArray *)linesWrappedToWidth:(int)width
{
	int length=[self length];
	NSMutableArray *wrapped=[NSMutableArray array];

	int linestartpos=0,lastspacepos=-1;
	for(int i=0;i<length;i++)
	{
		unichar c=[self characterAtIndex:i];
		if(c==' ') lastspacepos=i;

		int linelength=i-linestartpos;
		if(linelength>=width && lastspacepos!=-1)
		{
			[wrapped addObject:[self substringWithRange:NSMakeRange(linestartpos,lastspacepos-linestartpos)]];
			linestartpos=lastspacepos+1;
			lastspacepos=-1;
		}
	}

	if(linestartpos<length)
	[wrapped addObject:[self substringWithRange:NSMakeRange(linestartpos,length-linestartpos)]];

	return wrapped;
}

#ifdef __MINGW32__

+(int)terminalWidth
{
	return 80;
}

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

#include <sys/ioctl.h>

+(int)terminalWidth
{
    struct ttysize ts;
    ioctl(0,TIOCGSIZE,&ts);
	return ts.ts_cols;
}

-(void)printToFile:(FILE *)fh
{
	int length=[self lengthOfBytesUsingEncoding:NSUTF8StringEncoding]+1;
	char buffer[length+1];
	[self getCString:buffer maxLength:length+1 encoding:NSUTF8StringEncoding];

	fwrite(buffer,length,1,fh);
}

#endif

@end
