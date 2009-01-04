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
	uint8_t Index2Units[N_INDEXES],Units2Index[128];
	uint8_t *HeapStart,*PointerBase,*LowUnit,*HighUnit,*LastBreath;
	struct PPMAllocatorNode { struct PPMAllocatorNode *next; } FreeList[N_INDEXES];
} PPMSubAllocator;

BOOL StartSubAllocator(PPMSubAllocator *self,int SASize);
void StopSubAllocator(PPMSubAllocator *self);

void InitSubAllocator(PPMSubAllocator *self);
uint32_t AllocContext(PPMSubAllocator *self);
uint32_t AllocUnitsRare(PPMSubAllocator *self,int num);  // 1 unit == 12 bytes, NU <= 128
uint32_t ExpandUnits(PPMSubAllocator *self,uint32_t oldoffs,int oldnum);
uint32_t ShrinkUnits(PPMSubAllocator *self,uint32_t oldoffs,int oldnum,int newnum);
void FreeUnits(PPMSubAllocator *self,uint32_t offs,int num);

// TODO: Keep pointers as pointers on 32 bit, and offsets on 64 bit.

static inline void *OffsetToPointer(PPMSubAllocator *self,uint32_t offset)
{
	if(!offset) return NULL;
	return self->PointerBase+offset;
}

static inline uint32_t PointerToOffset(PPMSubAllocator *self,void *pointer)
{
	if(!pointer) return 0;
	return ((uintptr_t)pointer)-(uintptr_t)self->PointerBase;
}
