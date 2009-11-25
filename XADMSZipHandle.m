#import "XADMSZipHandle.h"

#include <zlib.h>

@implementation XADMSZipHandle

-(id)initWithHandle:(XADCABBlockHandle *)handle length:(off_t)length
{
	if(self=[super initWithName:[handle name] length:length])
	{
		blocks=[handle retain];
		[self setBlockPointer:buffer];
	}
	return self;
}

-(void)dealloc
{
	[blocks release];
	[super dealloc];
}

-(void)resetBlockStream
{
	[blocks seekToFileOffset:0];
}

-(int)produceBlockAtOffset:(off_t)pos
{
	if(pos!=0) [blocks skipToNextBlock];

	z_stream zs;
	memset(&zs,0,sizeof(zs));

	inflateInit2(&zs,-MAX_WBITS);
	inflateSetDictionary(&zs,buffer,lastlength);

	zs.avail_in=[blocks blockLength]-2;
	zs.next_in=[blocks blockPointer]+2;

	zs.next_out=buffer;
	zs.avail_out=sizeof(buffer);

	int err=inflate(&zs,0);
	inflateEnd(&zs);
	/*if(err==Z_STREAM_END)
	{
		if(seekback) [parent skipBytes:-(off_t)zs.avail_in];
		[self endStream];
		break;
	}
	else if(err!=Z_OK) [self _raiseZlib];*/

	lastlength=sizeof(buffer)-zs.avail_out;
	return lastlength;
}

@end
