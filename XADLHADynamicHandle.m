#import "XADLHADynamicHandle.h"
#import "XADException.h"

@implementation XADLHADynamicHandle

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length
{
	if(self=[super initWithHandle:handle length:length windowSize:4096])
	{
		static const int lengths[64]=
		{
			3,4,4,4,5,5,5,5,5,5,5,5,6,6,6,6,
			6,6,6,6,6,6,6,6,7,7,7,7,7,7,7,7,
			7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,
			8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,
		};

		distancecode=[[XADPrefixCode alloc] initWithLengths:lengths numberOfSymbols:64
		maximumLength:8 shortestCodeIsZeros:YES];
	}
	return self;
}

-(void)dealloc
{
	[distancecode release];
	[super dealloc];
}

-(void)resetLZSSHandle
{
	int numleaves=314;
	int numnodes=numleaves*2-1;

	memset(nodestorage,0,sizeof(nodestorage));

	for(int i=0;i<numnodes;i++) nodes[i]=&nodestorage[i];

	for(int i=0;i<numleaves;i++)
	{
		int index=numnodes-1-i;
		nodes[index]->index=index;
		nodes[index]->freq=1;
		nodes[index]->value=i;
	}

	for(int i=numleaves-2;i>=0;i--)
	{
		nodes[i]->index=i;
		nodes[i]->leftchild=nodes[2*i+1];
		nodes[i]->rightchild=nodes[2*i+2];
		nodes[i]->leftchild->parent=nodes[i];
		nodes[i]->rightchild->parent=nodes[i];
		nodes[i]->freq=nodes[i]->leftchild->freq+nodes[i]->rightchild->freq;
	}

	for(int i=0;i<256;i++) memset(&windowbuffer[i*13+18],i,13);
	for(int i=0;i<256;i++) windowbuffer[256*13+18+i]=i;
	for(int i=0;i<256;i++) windowbuffer[256*13+256+18+i]=255-i;
	memset(&windowbuffer[256*13+512+18],0,128);
	memset(&windowbuffer[256*13+512+128+18],' ',128-18);
}

-(int)nextLiteralOrOffset:(int *)offset andLength:(int *)length atPosition:(off_t)pos
{
	XADLHADynamicNode *node=&nodestorage[0];
	while(node->leftchild||node->rightchild)
	{
		if(CSInputNextBit(input)) node=node->leftchild;
		else node=node->rightchild;
		if(!node) [XADException raiseIllegalDataException];
	}

	[self updateNode:node];

	int lit=node->value;

	if(lit<0x100) return lit;
	else
	{
		*length=lit-0x100+3;

		int highbits=CSInputNextSymbolUsingCode(input,distancecode);
		int lowbits=CSInputNextBitString(input,6);
		*offset=(highbits<<6)+lowbits+1;

		return XADLZSSMatch;
	}
}

-(void)updateNode:(XADLHADynamicNode *)node
{
	if(nodestorage[0].freq==0x8000) [self reconstructTree];

	for(;;)
	{
		node->freq++;
		if(!node->parent) break;
		[self rearrangeNode:node];
		node=node->parent;
	}
}

-(void)rearrangeNode:(XADLHADynamicNode *)node
{
	XADLHADynamicNode *p=node;

	int p_index=p->index;
	int q_index=p->index;
	while(q_index>0 && nodes[q_index-1]->freq<p->freq) q_index--;

	if(q_index<p_index)
	{
		// Swap the nodes p and q
		XADLHADynamicNode *q=nodes[q_index];

		XADLHADynamicNode *new_q_parent=p->parent;
		XADLHADynamicNode *new_p_parent=q->parent;
		BOOL p_is_rightchild=(p->parent->rightchild==p);
		BOOL q_is_rightchild=(q->parent->rightchild==q);

		if(p_is_rightchild) p->parent->rightchild=q;
		else p->parent->leftchild=q;

		if(q_is_rightchild) q->parent->rightchild=p;
		else q->parent->leftchild=p;

		p->parent=new_p_parent;
		q->parent=new_q_parent;

		nodes[p_index]=q;
		nodes[p_index]->index=p_index;

		nodes[q_index]=p;
		nodes[q_index]->index=q_index;
	}
}

-(void)reconstructTree
{
	int numleaves=314;
	int numnodes=numleaves*2-1;

	XADLHADynamicNode *leafs[numleaves];
	int n=0;
	for(int i=0;i<numnodes;i++)
	{
		if(!nodes[i]->leftchild&&!nodes[i]->rightchild)
		{
			XADLHADynamicNode *leaf=nodes[i];
			leaf->freq=(leaf->freq+1)/2;
			leafs[n++]=leaf;
		}
	}

	int leaf_index=numleaves-1;
	int branch_index=numleaves-2;
	int node_index=numnodes-1;
	int pair_index=numnodes-2;

	while(node_index>=0)
	{
		while(node_index>=pair_index)
		{
			nodes[node_index]=leafs[leaf_index];
			nodes[node_index]->index=node_index;
			node_index--;
			leaf_index--;
		}

		XADLHADynamicNode *branch=&nodestorage[branch_index--];
		branch->leftchild=nodes[pair_index];
		branch->rightchild=nodes[pair_index+1];
		branch->leftchild->parent=branch;
		branch->rightchild->parent=branch;
		branch->freq=branch->leftchild->freq+branch->rightchild->freq;

		while(leaf_index>=0 && leafs[leaf_index]->freq<=branch->freq)
		{
			nodes[node_index]=leafs[leaf_index];
			nodes[node_index]->index=node_index;
			node_index--;
			leaf_index--;
		}

		nodes[node_index]=branch;
		nodes[node_index]->index=node_index;
		node_index--;
		pair_index-=2;
	}
	nodes[0]->parent=NULL;
}

@end
