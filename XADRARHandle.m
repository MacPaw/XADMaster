#import "XADRARHandle.h"
#import "SystemSpecific.h"

@implementation XADRARHandle

-(id)initWithHandle:(CSHandle *)handle stream:(XADRARStream *)stream
{
	if(self=[super initWithName:[handle name]])
	{
		sourcehandle=[handle retain];
		s=[stream retain];

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
	[s release];
	[super dealloc];
}

-(void)resetBlockStream
{
	part=0;
	[sourcehandle seekToFileOffset:s->parts[0].start];

	StartRARUnpacker(unpacker,s->parts[0].length,s->method,0);
	bytesdone=0;
}

-(int)produceBlockAtOffset:(off_t)pos
{
	if(bytesdone>=s->parts[part].length)
	{
		// Try to go to the next block
		if(++part<s->numparts)
		{
			[sourcehandle seekToFileOffset:s->parts[part].start];
			StartRARUnpacker(unpacker,s->parts[part].length,s->method,1);
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
	off_t end=s->parts[part].end;
	if(pos+length>end) length=end-pos;
	if(length<0) return 0;

	return [sourcehandle readAtMost:length toBuffer:buffer];
}

@end



@implementation XADRARStream

+(XADRARStream *)streamWithVersion:(int)version start:(off_t)start compressedSize:(off_t)compsize uncompressedSize:(off_t)size
{
	XADRARStream *stream=[[[self alloc] initWithVersion:version] autorelease];
	[stream addPartFrom:start compressedSize:compsize uncompressedSize:size];
	return stream;
}

-(id)initWithVersion:(int)version
{
	if(self=[super init])
	{
		method=version;
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

-(NSString *)description
{
	return [NSString stringWithFormat:@"<XADRARParts with %d %@, version %d>",numparts,numparts==1?@"entry":@"entries",method];
}

@end
