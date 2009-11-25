#import "CSBlockStreamHandle.h"

@interface XADCABBlockHandle:CSBlockStreamHandle
{
	CSHandle *parent;
	int extbytes;

	int numfolders;
	off_t offsets[100];
	int numblocks[100];

	int currentfolder,currentblock;

	uint8_t buffer[32768+6144];
}

-(id)initWithHandle:(CSHandle *)handle reservedBytes:(int)reserved;
-(void)dealloc;

-(void)addFolderAtOffset:(off_t)startoffs numberOfBlocks:(int)numblocks;
-(off_t)scanLengths;

-(void)resetBlockStream;
-(int)produceBlockAtOffset:(off_t)pos;

@end