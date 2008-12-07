#import "XADRARHandle.h"

@implementation XADRARHandle

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length version:(int)version
{
	if(self=[super initWithName:[handle name] length:length])
	{
		sourcehandle=[handle retain];
		startoffs=[handle offsetInFile];
		method=version;
		unpacker=AllocRARUnpacker((RARReadFunc)
		[sourcehandle methodForSelector:@selector(readAtMost:toBuffer:)],
		sourcehandle,@selector(readAtMost:toBuffer:));
	}
	return self;
}

-(void)dealloc
{
	FreeRARUnpacker(unpacker);
	[sourcehandle release];
	[super dealloc];
}

-(void)resetBlockStream
{
	[sourcehandle seekToFileOffset:startoffs];
	StartRARUnpacker(unpacker,streamlength,method,0);
}

-(int)produceBlockAtOffset:(off_t)pos
{
	int length;
	[self setBlockPointer:NextRARBlock(unpacker,&length)];
	return length;
}

@end
