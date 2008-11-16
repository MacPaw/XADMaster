#import "XADArchiveParser.h"
#import "xadmaster.h"

@interface XADLibXADParser:XADArchiveParser
{
//	XADArchivePipe *pipe;
//	XADError lasterror;

	struct xadMasterBase *xmb;
	struct xadArchiveInfo *archive;
	struct Hook inhook,progresshook;

	BOOL addonbuild;
	int numadded;
}

+(int)requiredHeaderSize;
+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name;

-(id)initWithHandle:(CSHandle *)handle name:(NSString *)name;
-(void)dealloc;

-(void)parse;
-(void)newEntryCallback:(struct xadProgressInfo *)proginfo;
-(NSMutableDictionary *)dictionaryForFileInfo:(struct xadFileInfo *)info;

-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)properties;

-(NSString *)formatName;

@end
