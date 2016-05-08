#import "CSSegmentedHandle.h"

#define CSMultiFileHandle XADMultiFileHandle

@interface CSMultiFileHandle:CSSegmentedHandle
{
	NSArray *paths;
}

+(CSHandle *)handleWithPathArray:(NSArray *)patharray;
+(CSHandle *)handleWithPaths:(CSHandle *)firstpath,...;

// Initializers
-(id)initWithPaths:(NSArray *)patharray;
-(id)initAsCopyOf:(CSMultiFileHandle *)other;
-(void)dealloc;

// Public methods
-(NSArray *)paths;

// Implemented by this class
-(NSInteger)numberOfSegments;
-(off_t)segmentSizeAtIndex:(NSInteger)index;
-(CSHandle *)handleAtIndex:(NSInteger)index;

// Internal methods
-(void)_raiseError;

@end
