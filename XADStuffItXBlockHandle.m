#import "XADStuffItXBlockHandle.h"

// TODO: figure out actual block structure instead of hardcoding to 65536

@implementation XADStuffItXBlockHandle

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
	[self setBlockPointer:buffer];
}

-(int)produceBlockAtOffset:(off_t)pos
{
	int something1=[parent readUInt8];
	int something2=[parent readUInt8];
	int something3=[parent readUInt8];
	if(something1!=5) [self endBlockStream];

	return [parent readAtMost:65536 toBuffer:buffer];
}

@end
