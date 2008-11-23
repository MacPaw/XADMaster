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

	NSMutableData *namedata;
}

+(int)requiredHeaderSize;
+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name;

-(id)initWithHandle:(CSHandle *)handle name:(NSString *)name;
-(void)dealloc;

-(char *)encodedName;

-(void)parse;
-(void)newEntryCallback:(struct xadProgressInfo *)proginfo;
-(NSMutableDictionary *)dictionaryForFileInfo:(struct xadFileInfo *)info;

-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)properties wantChecksum:(BOOL)checksum;

-(NSString *)formatName;

@end
