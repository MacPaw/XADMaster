#import "CSSegmentedHandle.h"

#define CSMultiHandle XADMultiHandle

@interface CSMultiHandle:CSSegmentedHandle
{
	NSArray *handles;
}

+(CSHandle *)handleWithHandleArray:(NSArray *)handlearray;
+(CSHandle *)handleWithHandles:(CSHandle *)firsthandle,...;

// Initializers
-(id)initWithHandles:(NSArray *)handlearray;
-(id)initAsCopyOf:(CSMultiHandle *)other;
-(void)dealloc;

// Public methods
-(NSArray *)handles;

// Implemented by this class
-(NSInteger)numberOfSegments;
-(off_t)segmentSizeAtIndex:(NSInteger)index;
-(CSHandle *)handleAtIndex:(NSInteger)index;

@end
