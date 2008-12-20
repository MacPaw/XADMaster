#import "XADRARHandle.h"
#import "SystemSpecific.h"

@implementation XADRARHandle

-(id)initWithHandle:(CSHandle *)handle parts:(XADRARParts *)parts version:(int)version
{
	if(self=[super initWithName:[handle name]])
	{
		sourcehandle=[handle retain];
		p=[parts retain];
		method=version;

		unpacker=AllocRARUnpacker(
		(RARReadFunc)[self methodForSelector:@selector(provideInput:buffer:)],
		self,@selector(provideInput:buffer:));
	}
	return self;
}

-(void)dealloc
{
	FreeRARUnpacker(unpacker);
	[sourcehandle release];
	[p release];
	[super dealloc];
}

-(void)resetBlockStream
{
	part=0;
	[sourcehandle seekToFileOffset:p->parts[0].start];

	StartRARUnpacker(unpacker,p->parts[0].length,method,0);
	bytesdone=0;
}

-(int)produceBlockAtOffset:(off_t)pos
{
	if(bytesdone>=p->parts[part].length)
	{
		// Try to go to the next block
		if(++part<p->numparts)
		{
			[sourcehandle seekToFileOffset:p->parts[part].start];
			StartRARUnpacker(unpacker,p->parts[part].length,method,1);
			bytesdone=0;
		}
		else return 0;
	}

	int length;
	[self setBlockPointer:NextRARBlock(unpacker,&length)];

	bytesdone+=length;

	return length;
}

-(int)provideInput:(int)length buffer:(void *)buffer
{
	off_t pos=[sourcehandle offsetInFile];
	off_t end=p->parts[part].end;
	if(pos+length>end) length=end-pos;
	if(length<0) return 0;

	return [sourcehandle readAtMost:length toBuffer:buffer];
}

@end



@implementation XADRARParts

+(XADRARParts *)partWithStart:(off_t)start compressedSize:(off_t)compsize uncompressedSize:(off_t)size
{
	XADRARParts *part=[[self new] autorelease];
	[part addPartFrom:start compressedSize:compsize uncompressedSize:size];
	return part;
}

-(id)init
{
	if(self=[super init])
	{
		numparts=0;
		parts=NULL;
	}
	return self;
}

-(void)dealloc
{
	free(parts);
	[super dealloc];
}

-(void)addPartFrom:(off_t)fileoffset compressedSize:(off_t)compsize uncompressedSize:(off_t)size
{
	parts=reallocf(parts,sizeof(parts[0])*(numparts+1));

	parts[numparts].start=fileoffset;
	parts[numparts].end=fileoffset+compsize;
	parts[numparts].length=size;
	numparts++;
}

-(int)count { return numparts; }

-(off_t)outputStartOffsetForPart:(int)part
{
	off_t start=0;
	for(int i=0;i<part;i++) start+=parts[i].length;
	return start;
}

-(off_t)outputSizeForPart:(int)part { return parts[part].length; }

-(NSString *)description
{
	return [NSString stringWithFormat:@"<XADRARParts with %d %@>",numparts,numparts==1?@"entry":@"entries"];
}

@end
