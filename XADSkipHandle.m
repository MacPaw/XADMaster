#import "XADSkipHandle.h"

static off_t SkipStart(XADSkip *skips,int index) { return skips[index].start; }
static off_t SkipEnd(XADSkip *skips,int index) { return skips[index].start+skips[index].length; }
static off_t SkipLength(XADSkip *skips,int index) { return skips[index].length; }

static XADSkip FindIndexOfSkipBefore(off_t pos,XADSkip *skips,int numskips)
{
	int first=0,last=numskips-1;

	if(numskips==0||SkipStart(skips,0)>pos) return -1;
	if(SkipEnd(skips,0)>pos) return 0;
	if(SkipStart(skips,last)<=pos) return last;

	while(last-first>1)
	{
		int mid=(last+first)/2;
		if(SkipStart(skips,mid)<=pos)
		{
			if(SkipEnd(skips,mid)>pos) return mid;
			first=mid;
		}
		else last=mid;
	}
	return first;
}

@implementation XADSkipHandle

-(id)initWithHandle:(CSHandle *)handle
{
	if(self=[super initWithName:[handle name])
	{
		parent=[handle retain];
	}
	return self;
}

-(id)initAsCopyOf:(XADSkipHandle *)other
{
	if(self=[super initAsCopyOf:other])
	{
		parent=[other->parent copy];
	}
	return self;
}

-(void)dealloc
{
	[parent release];
	[super dealloc];
}

-(off_t)fileSize
{
	off_t size=[parent fileSize];
	if(size==CSHandleMaxLength) return CSHandleMaxLength;

	
}

-(off_t)offsetInFile
{
	off_t offs=[parent offsetInFile];
}

-(BOOL)atEndOfFile
{
}

-(void)seekToFileOffset:(off_t)offs
{
}

-(void)seekToEndOfFile
{
	currhandle==[handles count]-1;
	[(CSHandle *)[handles objectAtIndex:currhandle] seekToEndOfFile];
}

-(int)readAtMost:(int)num toBuffer:(void *)buffer
{
	off_t total=0;
	for(;;)
	{
		off_t actual=[[handles objectAtIndex:currhandle] readAtMost:num-total toBuffer:((char *)buffer)+total];
		total+=actual;
		if(total==num||currhandle==[handles count]-1) return total;
		currhandle++;
		[[handles objectAtIndex:currhandle] seekToFileOffset:0];
	}
}


@end
