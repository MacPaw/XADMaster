#import <Foundation/Foundation.h>

#define N1 4
#define N2 4
#define N3 4
#define N4 ((128+3-1*N1-2*N2-3*N3)/4)
#define UNIT_SIZE 12
#define N_INDEXES (N1+N2+N3+N4)

typedef struct PPMSubAllocator
{
	long SubAllocatorSize;
	uint8_t Indx2Units[N_INDEXES],Units2Indx[128];
	uint8_t *HeapStart,*LoUnit,*HiUnit,*LastBreath;
	struct NODE { struct NODE *next; } FreeList[N_INDEXES];
} PPMSubAllocator;

BOOL StartSubAllocator(PPMSubAllocator *self,int SASize);
void StopSubAllocator(PPMSubAllocator *self);

void InitSubAllocator(PPMSubAllocator *self);
void *AllocContext(PPMSubAllocator *self);
void *AllocUnitsRare(PPMSubAllocator *self,int NU); /* 1 unit == 12 bytes, NU <= 128 */
void *ExpandUnits(PPMSubAllocator *self,void *ptr,int OldNU);
void *ShrinkUnits(PPMSubAllocator *self,void *ptr,int OldNU,int NewNU);
void FreeUnits(PPMSubAllocator *self,void *ptr,int OldNU);
