#import "CSHandle.h"

#import <stdio.h>

#define CSFileHandle XADFileHandle

extern NSString *CSCannotOpenFileException;
extern NSString *CSFileErrorException;

@interface CSFileHandle:CSHandle
{
	FILE *fh;
	NSString *path;
	BOOL close;

	NSLock *multilock;
	CSFileHandle *fhowner;
	off_t pos;
}

+(CSFileHandle *)fileHandleForReadingAtPath:(NSString *)path;
+(CSFileHandle *)fileHandleForWritingAtPath:(NSString *)path;
+(CSFileHandle *)fileHandleForPath:(NSString *)path modes:(NSString *)modes;
+(CSFileHandle *)fileHandleForStandardInput;
+(CSFileHandle *)fileHandleForStandardOutput;
+(CSFileHandle *)fileHandleForStandardError;

// Initializers
-(id)initWithFilePointer:(FILE *)file closeOnDealloc:(BOOL)closeondealloc path:(NSString *)filepath;
-(id)initAsCopyOf:(CSFileHandle *)other;
-(void)dealloc;
-(void)close;

// Public methods
-(FILE *)filePointer;

// Implemented by this class
-(off_t)fileSize;
-(off_t)offsetInFile;
-(BOOL)atEndOfFile;

-(void)seekToFileOffset:(off_t)offs;
-(void)seekToEndOfFile;
-(void)pushBackByte:(int)byte;
-(int)readAtMost:(int)num toBuffer:(void *)buffer;
-(void)writeBytes:(int)num fromBuffer:(const void *)buffer;

-(NSString *)name;

// Internal methods
-(void)_raiseError;
-(void)_setMultiMode;

@end
