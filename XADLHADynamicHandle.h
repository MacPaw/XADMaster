#import "XADLZSSHandle.h"
#import "XADPrefixCode.h"

typedef struct XADLHADynamicNode XADLHADynamicNode;

struct XADLHADynamicNode
{
	XADLHADynamicNode *parent,*leftchild,*rightchild;
	int index,freq,value;
};

@interface XADLHADynamicHandle:XADLZSSHandle
{
	XADPrefixCode *distancecode;
	XADLHADynamicNode *nodes[314*2-1],nodestorage[314*2-1];
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length;
-(void)dealloc;

-(void)resetLZSSHandle;
-(int)nextLiteralOrOffset:(int *)offset andLength:(int *)length atPosition:(off_t)pos;

-(void)updateNode:(XADLHADynamicNode *)node;
-(void)rearrangeNode:(XADLHADynamicNode *)node;
-(void)reconstructTree;

@end
