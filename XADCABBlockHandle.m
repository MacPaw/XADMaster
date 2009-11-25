#import "XADCABBlockHandle.h"
#import "XADException.h"

@implementation XADCABBlockHandle

-(id)initWithHandle:(CSHandle *)handle reservedBytes:(int)reserved
{
	if(self=[super initWithName:[handle name]])
	{
		parent=[handle retain];
		extbytes=reserved;
		numfolders=0;

		[self setBlockPointer:buffer];
	}
	return self;
}

-(void)dealloc
{
	[parent release];
	[super dealloc];
}



-(void)addFolderAtOffset:(off_t)startoffs numberOfBlocks:(int)num
{
	if(numfolders==sizeof(offsets)/sizeof(offsets[0])) [XADException raiseNotSupportedException];

	offsets[numfolders]=startoffs;
	numblocks[numfolders]=num;
	numfolders++;
}

-(off_t)scanLengths
{
	off_t complen=0;
	off_t uncomplen=0;

	for(int folder=0;folder<numfolders;folder++)
	{
		[parent seekToFileOffset:offsets[folder]];

		for(int block=0;block<numblocks[folder];block++)
		{
			uint32_t check=[parent readUInt32LE];
			int compbytes=[parent readUInt16LE];
			int uncompbytes=[parent readUInt16LE];
			[parent skipBytes:extbytes+compbytes];

			complen+=compbytes;
			uncomplen+=uncompbytes;
		}
	}

	[self setStreamLength:complen];

	return uncomplen;
}


-(void)resetBlockStream
{
	[parent seekToFileOffset:offsets[0]];
	currentfolder=0;
	currentblock=0;
}

-(int)produceBlockAtOffset:(off_t)pos
{
	uint32_t check=[parent readUInt32LE];
	int compbytes=[parent readUInt16LE];
	int uncompbytes=[parent readUInt16LE];
	[parent skipBytes:extbytes];

	if(compbytes>sizeof(buffer)) [XADException raiseIllegalDataException];

	[parent readBytes:compbytes toBuffer:buffer];

	int totalbytes=compbytes;
	while(uncompbytes==0)
	{
		currentblock=0;
		currentfolder++;

		if(currentfolder>=numfolders) [XADException raiseIllegalDataException];

		[parent seekToFileOffset:offsets[currentfolder]];
		check=[parent readUInt32LE];
		compbytes=[parent readUInt16LE];
		uncompbytes=[parent readUInt16LE];
		[parent skipBytes:extbytes];

		if(compbytes+totalbytes>sizeof(buffer)) [XADException raiseIllegalDataException];

		[parent readBytes:compbytes toBuffer:&buffer[totalbytes]];
		totalbytes+=compbytes;
	}

	currentblock++;
	if(currentblock>=numblocks[currentfolder])
	{
		if(currentfolder==numfolders-1) [self endBlockStream];
		else // Can this happen? Not sure, supporting it anyway.
		{
			currentblock=0;
			currentfolder++;
			[parent seekToFileOffset:offsets[currentfolder]];
		}
	}

	return totalbytes;
}

@end
