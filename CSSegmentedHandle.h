#import "CSHandle.h"

#define CSSegmentedHandle XADSegmentedHandle

extern NSString *CSNoSegmentsException;
extern NSString *CSSizeOfSegmentUnknownException;

@interface CSSegmentedHandle:CSHandle
{
	NSInteger count;
	NSInteger currindex;
	CSHandle *currhandle;
	off_t *segmentends;
	NSArray *segmentsizes;
}

// Initializers
-(id)init;
-(id)initAsCopyOf:(CSSegmentedHandle *)other;
-(void)dealloc;

// Public methods
-(CSHandle *)currentHandle;
-(NSArray *)segmentSizes;

// Implemented by this class
-(off_t)fileSize;
-(off_t)offsetInFile;
-(BOOL)atEndOfFile;

-(void)seekToFileOffset:(off_t)offs;
-(void)seekToEndOfFile;
-(int)readAtMost:(int)num toBuffer:(void *)buffer;

-(NSString *)name;
-(NSString *)description;

// Implemented by subclasses
-(NSInteger)numberOfSegments;
-(off_t)segmentSizeAtIndex:(NSInteger)index;
-(CSHandle *)handleAtIndex:(NSInteger)index;

// Internal methods
-(void)_open;
-(void)_setCurrentIndex:(NSInteger)newindex;
-(void)_raiseNoSegments;
-(void)_raiseSizeUnknownForSegment:(NSInteger)i;

@end
