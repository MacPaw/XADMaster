#import "XADMSZipHandle.h"

@implementation XADMSZipHandle

-(id)initWithHandle:(CSHandle *)handle
{
	if(self=[super initWithName:[handle name]])
	{
		parent=[handle retain];
		startoffs=[parent offsetInFile];
	}
	return self;
}

-(void)dealloc
{
	[parent release];
	[super dealloc];
}

-(void)resetBlockStream
{
	[parent seekToFileOffset:startoffs];
}

-(int)produceBlockAtOffset:(off_t)pos
{
/*	int size=ReadSitxP2(parent);
	if(!size) return -1;

	buffer=reallocf(buffer,size);
	[self setBlockPointer:buffer];

	return [parent readAtMost:size toBuffer:buffer];*/
	return 0;
}

@end
