#import "PPMSubAllocator.h"

#include <stdlib.h>
#include <string.h>

typedef struct NODE NODE;

void InsertNode(PPMSubAllocator *self,void *p,int indx) {
    ((struct NODE *)p)->next=self->FreeList[indx].next;
	self->FreeList[indx].next=(NODE*) p;
}

void* RemoveNode(PPMSubAllocator *self,int indx) {
    NODE* RetVal=self->FreeList[indx].next;
	self->FreeList[indx].next=RetVal->next;
    return RetVal;
}

unsigned int I2B(PPMSubAllocator *self,int indx) { return UNIT_SIZE*self->Indx2Units[indx]; }

void SplitBlock(PPMSubAllocator *self,void* pv,int OldIndx,int NewIndx)
{
    int i, UDiff=self->Indx2Units[OldIndx]-self->Indx2Units[NewIndx];
    uint8_t* p=((uint8_t*) pv)+I2B(self,NewIndx);
    if (self->Indx2Units[i=self->Units2Indx[UDiff-1]] != UDiff) {
        InsertNode(self,p,--i);                  p += I2B(self,i);
        UDiff -= self->Indx2Units[i];
    }
    InsertNode(self,p,self->Units2Indx[UDiff-1]);
}

uint32_t GetUsedMemory(PPMSubAllocator *self)
{
    uint32_t i, k, RetVal=self->SubAllocatorSize-(self->HiUnit-self->LoUnit);
    for (k=i=0;i < N_INDEXES;i++, k=0) {
        for (NODE* pn=self->FreeList+i;(pn=pn->next) != NULL;k++)
                ;
        RetVal -= UNIT_SIZE*self->Indx2Units[i]*k;
    }
    if ( self->LastBreath ) RetVal -= 128*128*UNIT_SIZE;
    return (RetVal >> 2);
}

void StopSubAllocator(PPMSubAllocator *self) {
    if ( self->SubAllocatorSize ) {
        self->SubAllocatorSize=0;
		free(self->HeapStart);
    }
}
BOOL StartSubAllocator(PPMSubAllocator *self,int SASize)
{
    uint32_t t=SASize;
    if (self->SubAllocatorSize == t) return TRUE;
    StopSubAllocator(self);
    if ((self->HeapStart=malloc(t)) == NULL) return FALSE;
    self->SubAllocatorSize=t;
	return TRUE;
}
void InitSubAllocator(PPMSubAllocator *self)
{
    int i, k;
    memset(self->FreeList,0,sizeof(self->FreeList));
    self->HiUnit=(self->LoUnit=self->HeapStart)+UNIT_SIZE*(self->SubAllocatorSize/UNIT_SIZE);
    self->LastBreath=self->LoUnit;                      self->LoUnit += 128*128*UNIT_SIZE;
    for (i=0,k=1;i < N1     ;i++,k += 1)    self->Indx2Units[i]=k;
    for (k++;i < N1+N2      ;i++,k += 2)    self->Indx2Units[i]=k;
    for (k++;i < N1+N2+N3   ;i++,k += 3)    self->Indx2Units[i]=k;
    for (k++;i < N1+N2+N3+N4;i++,k += 4)    self->Indx2Units[i]=k;
    for (k=i=0;k < 128;k++) {
        i += (self->Indx2Units[i] < k+1);         self->Units2Indx[k]=i;
    }
}

void *AllocUnitsRare(PPMSubAllocator *self,int NU)
{
    int i, indx=self->Units2Indx[NU-1];
    if ( self->FreeList[indx].next ) return RemoveNode(self,indx);
    void* RetVal=self->LoUnit;
	self->LoUnit += I2B(self,indx);
    if (self->LoUnit <= self->HiUnit)                   return RetVal;
    if ( self->LastBreath ) {
        for (i=0;i < 128;i++) {
            InsertNode(self,self->LastBreath,N_INDEXES-1);
            self->LastBreath += 128*UNIT_SIZE;
        }
        self->LastBreath=NULL;
    }
    self->LoUnit -= I2B(self,indx);
	i=indx;
    do {
        if (++i == N_INDEXES)               return NULL;
    } while ( !self->FreeList[i].next );
    SplitBlock(self,RetVal=RemoveNode(self,i),i,indx);
    return RetVal;
}
void* AllocContext(PPMSubAllocator *self)
{
    if (self->HiUnit != self->LoUnit) return (self->HiUnit -= UNIT_SIZE);
    return AllocUnitsRare(self,1);
}
void* ExpandUnits(PPMSubAllocator *self,void* OldPtr,int OldNU)
{
    int i0=self->Units2Indx[OldNU-1], i1=self->Units2Indx[OldNU-1+1];
    if (i0 == i1)                           return OldPtr;
    void* ptr=AllocUnitsRare(self,OldNU+1);
    if ( ptr ) {
        memcpy(ptr,OldPtr,I2B(self,i0));
		InsertNode(self,OldPtr,i0);
    }
    return ptr;
}
void* ShrinkUnits(PPMSubAllocator *self,void* OldPtr,int OldNU,int NewNU)
{
    int i0=self->Units2Indx[OldNU-1], i1=self->Units2Indx[NewNU-1];
    if (i0 == i1)                           return OldPtr;
    if ( self->FreeList[i1].next ) {
        void* ptr=RemoveNode(self,i1);
		memcpy(ptr,OldPtr,I2B(self,i1));
        InsertNode(self,OldPtr,i0);              return ptr;
    } else {
        SplitBlock(self,OldPtr,i0,i1);           return OldPtr;
    }
}
void FreeUnits(PPMSubAllocator *self,void* ptr,int OldNU)
{
    InsertNode(self,ptr,self->Units2Indx[OldNU-1]);
}
