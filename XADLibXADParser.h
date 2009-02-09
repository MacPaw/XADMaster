#import "XADArchiveParser.h"
#import "CSMemoryHandle.h"
#import "libxad/include/functions.h"

@interface XADLibXADParser:XADArchiveParser
{
//	XADArchivePipe *pipe;
//	XADError lasterror;

	struct xadArchiveInfoP *archive;
	struct Hook inhook,progresshook;

	struct XADInHookData
	{
		CSHandle *fh;
		const char *name;
	} indata;

	BOOL addonbuild;
	int numadded;

	NSMutableData *namedata;
}

+(int)requiredHeaderSize;
+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name;

-(id)initWithHandle:(CSHandle *)handle name:(NSString *)name;
-(void)dealloc;

-(void)parse;
-(void)newEntryCallback:(struct xadProgressInfo *)proginfo;
-(NSMutableDictionary *)dictionaryForFileInfo:(struct xadFileInfo *)info;

-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum;

-(NSString *)formatName;

@end



@interface XADLibXADMemoryHandle:CSMemoryHandle
{
	BOOL success;
}

-(id)initWithData:(NSData *)data successfullyExtracted:(BOOL)wassuccess;
-(BOOL)hasChecksum;
-(BOOL)isChecksumCorrect;

@end
