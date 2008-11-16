#import <CSFilterHandle.h>

@interface XADPrefixTree:NSObject
{
	int (*tree)[2];
	int numentries;
	BOOL isstatic;
}

+(XADPrefixTree *)prefixTree;

-(id)init;
-(id)initWithStaticTable:(int (*)[2])statictable;
-(void)dealloc;

-(void)addValue:(int)value forCode:(int)code length:(int)length;
-(void)addValue:(int)value forCode:(int)code length:(int)length repeatAt:(int)repeatpos;

@end

int CSFilterNextSymbolFromTree(CSFilterHandle *filter,XADPrefixTree *tree);
int CSFilterNextSymbolFromTreeLE(CSFilterHandle *filter,XADPrefixTree *tree);
