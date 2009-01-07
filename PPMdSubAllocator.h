#import <Foundation/Foundation.h>

#define N1 4
#define N2 4
#define N3 4
#define N4 ((128+3-1*N1-2*N2-3*N3)/4)
#define UNIT_SIZE 12
#define N_INDEXES (N1+N2+N3+N4)

typedef struct PPMdSubAllocator
{
	void (*Init)(PPMdSubAllocator *self);
	uint32_t (*AllocContext)(PPMdSubAllocator *self);
	uint32_t (*AllocUnits)(PPMdSubAllocator *self,int num);  // 1 unit == 12 bytes, NU <= 128
	uint32_t (*ExpandUnits)(PPMdSubAllocator *self,uint32_t oldoffs,int oldnum);
	uint32_t (*ShrinkUnits)(PPMdSubAllocator *self,uint32_t oldoffs,int oldnum,int newnum);
	void (*FreeUnits)(PPMdSubAllocator *self,uint32_t offs,int num);
} PPMdSubAllocator;

typedef struct PPMdSubAllocatorVariantG
{
	PPMDSubAllocator core;

	long SubAllocatorSize;
	uint8_t Index2Units[N_INDEXES],Units2Index[128];
	uint8_t *LowUnit,*HighUnit,*LastBreath;
	struct PPMAllocatorNode { struct PPMAllocatorNode *next; } FreeList[N_INDEXES];
	uint8_t HeapStart[0];
} PPMdSubAllocatorVariantG;

PPMdSubAllocatorVariantG *CreateSubAllocatorVariantG(int size);
void FreeSubAllocatorVariantG(PPMdSubAllocatorVariantG *alloc);

static inline void InitSubAllocator(PPMdSubAllocator *self) { self->Init(self); };
static inline uint32_t AllocContext(PPMdSubAllocator *self) { return self->AllocContext(self); }
static inline uint32_t AllocUnits(PPMdSubAllocator *self,int num) { return self->AllocUnits(self,num); }
static inline uint32_t ExpandUnits(PPMdSubAllocator *self,uint32_t oldoffs,int oldnum) { return self->ExpandUnits(self,oldoffs,oldnum); }
static inline uint32_t ShrinkUnits(PPMdSubAllocator *self,uint32_t oldoffs,int oldnum,int newnum) { return self->ShrinkUnits(self,oldnum,newnum); }
void FreeUnits(PPMdSubAllocator *self,uint32_t offs,int num) { return self->FreeUnits(self,offs,num); }

// TODO: Keep pointers as pointers on 32 bit, and offsets on 64 bit.

static inline void *OffsetToPointer(PPMdSubAllocator *self,uint32_t offset)
{
	if(!offset) return NULL;
	return ((uint8_t *)self)+offset;
}

static inline uint32_t PointerToOffset(PPMdSubAllocator *self,void *pointer)
{
	if(!pointer) return 0;
	return ((uintptr_t)pointer)-(uintptr_t)self;
}
