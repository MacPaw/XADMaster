#import "CSFilterHandle.h"

typedef struct XADZipShrinkTreeNode
{
	uint16_t chr;
	int16_t parent;
} XADZipShrinkTreeNode;

@interface XADZipShrinkHandle:CSFilterHandle
{
	int numsymbols,symbolsize;
	XADZipShrinkTreeNode *nodes;

	int prevsymbol;

	int currbyte,numbytes;
	uint8_t buffer[8192];
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length;
-(void)dealloc;

-(void)clearTable;

-(void)resetFilter;
-(uint8_t)produceByteAtOffset:(off_t)pos;

@end
