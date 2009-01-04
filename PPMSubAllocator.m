#import "PPMSubAllocator.h"

#include <stdlib.h>
#include <string.h>

void InsertNode(PPMSubAllocator *self,void *p,int index)
{
	((struct PPMAllocatorNode *)p)->next=self->FreeList[index].next;
	self->FreeList[index].next=p;
}

void *RemoveNode(PPMSubAllocator *self,int index)
{
	struct PPMAllocatorNode *node=self->FreeList[index].next;
	self->FreeList[index].next=node->next;
	return node;
}

unsigned int I2B(PPMSubAllocator *self,int index) { return UNIT_SIZE*self->Index2Units[index]; }

void SplitBlock(PPMSubAllocator *self,void *pv,int oldindex,int newindex)
{
	uint8_t *p=((uint8_t *)pv)+I2B(self,newindex);

	int diff=self->Index2Units[oldindex]-self->Index2Units[newindex];
	int i=self->Units2Index[diff-1];
	if(self->Index2Units[i]!=diff)
	{
		InsertNode(self,p,i-1);
		p+=I2B(self,i-1);
        diff-=self->Index2Units[i-1];
    }

    InsertNode(self,p,self->Units2Index[diff-1]);
}

uint32_t GetUsedMemory(PPMSubAllocator *self)
{
	uint32_t size=self->SubAllocatorSize-(self->HighUnit-self->LowUnit);

	for(int i=0;i<N_INDEXES;i++)
	{
		int k=0;
		struct PPMAllocatorNode *node=&self->FreeList[i];
		while(node=node->next) k++;

		size-=UNIT_SIZE*self->Index2Units[i]*k;
    }

    if(self->LastBreath) size-=128*128*UNIT_SIZE;

	return size>>2;
}



BOOL StartSubAllocator(PPMSubAllocator *self,int size)
{
    if(self->SubAllocatorSize==size) return YES;

    StopSubAllocator(self);

	self->HeapStart=malloc(size);
    if(!self->HeapStart) return NO;

    self->SubAllocatorSize=size;
	return YES;
}

void StopSubAllocator(PPMSubAllocator *self)
{
	if(self->SubAllocatorSize)
	{
		self->SubAllocatorSize=0;
		free(self->HeapStart);
	}
}

void InitSubAllocator(PPMSubAllocator *self)
{
	memset(self->FreeList,0,sizeof(self->FreeList));

	self->LowUnit=self->HeapStart;
	self->HighUnit=self->HeapStart+UNIT_SIZE*(self->SubAllocatorSize/UNIT_SIZE);
	self->LastBreath=self->LowUnit;
	self->LowUnit+=128*128*UNIT_SIZE;

	for(int i=0;i<N1;i++) self->Index2Units[i]=1+i;
    for(int i=0;i<N2;i++) self->Index2Units[N1+i]=2+N1+i*2;
    for(int i=0;i<N3;i++) self->Index2Units[N1+N2+i]=3+N1+2*N2+i*3;
	for(int i=0;i<N4;i++) self->Index2Units[N1+N2+N3+i]=4+N1+2*N2+3*N3+i*4;

	int i=0;
    for(int k=0;k<128;k++)
	{
        if(self->Index2Units[i]<k+1) i++;
		self->Units2Index[k]=i;
    }
}

void *AllocContext(PPMSubAllocator *self)
{
    if(self->HighUnit!=self->LowUnit)
	{
		self->HighUnit-=UNIT_SIZE;
		return self->HighUnit;
	}

    return AllocUnitsRare(self,1);
}

void *AllocUnitsRare(PPMSubAllocator *self,int num)
{
	int index=self->Units2Index[num-1];
	if(self->FreeList[index].next) return RemoveNode(self,index);

	if(self->LowUnit<=self->HighUnit)
	{
		void *units=self->LowUnit;
		self->LowUnit+=I2B(self,index);
		return units;
	}

	if(self->LastBreath)
	{
		uint8_t *ptr=self->LastBreath;
		for(int i=0;i<128;i++)
		{
			InsertNode(self,ptr,N_INDEXES-1);
			ptr+=128*UNIT_SIZE;
		}
		self->LastBreath=NULL;
	}

	for(int i=index+1;i<N_INDEXES;i++)
	{
		if(self->FreeList[i].next)
		{
			void *units=RemoveNode(self,i);
			SplitBlock(self,units,i,index);
			return units;
		}
	}

	return NULL;
}

void *ExpandUnits(PPMSubAllocator *self,void *oldptr,int oldnum)
{
	int oldindex=self->Units2Index[oldnum-1];
	int newindex=self->Units2Index[oldnum];
	if(oldindex==newindex) return oldptr;

	void *ptr=AllocUnitsRare(self,oldnum+1);
	if(ptr)
	{
		memcpy(ptr,oldptr,I2B(self,oldindex));
		InsertNode(self,oldptr,oldindex);
	}
	return ptr;
}

void *ShrinkUnits(PPMSubAllocator *self,void *oldptr,int oldnum,int newnum)
{
	int oldindex=self->Units2Index[oldnum-1];
	int newindex=self->Units2Index[newnum-1];
	if(oldindex==newindex) return oldptr;

	if(self->FreeList[newindex].next)
	{
		void *ptr=RemoveNode(self,newindex);
		memcpy(ptr,oldptr,I2B(self,newindex));
		InsertNode(self,oldptr,oldindex);
		return ptr;
    }
	else
	{
		SplitBlock(self,oldptr,oldindex,newindex);
		return oldptr;
    }
}

void FreeUnits(PPMSubAllocator *self,void *ptr,int num)
{
	InsertNode(self,ptr,self->Units2Index[num-1]);
}
