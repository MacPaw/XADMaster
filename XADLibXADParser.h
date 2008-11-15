#import "XADArchiveParser.h"
#import "xadmaster.h"

@interface XADLibXADParser:XADArchiveParser
{
	XADArchivePipe *pipe;
	XADError lasterror;

	NSString *filename;
	NSArray *volumes;
	NSData *memdata;
	XADArchive *parentarchive;

	id delegate;
	NSStringEncoding name_encoding;
	NSString *password;
	NSTimeInterval update_interval;
	double update_time;

	struct xadMasterBase *xmb;
	struct xadArchiveInfo *archive;
	struct Hook progresshook;

	NSMutableArray *fileinfos;
	NSMutableDictionary *dittoforks;
	NSMutableArray *writeperms;

	int currentry;
	xadSize extractsize,totalsize;
	NSString *immediatedestination;
	BOOL immediatefailed;

	UniversalDetector *detector;
	NSStringEncoding detected_encoding;
	float detector_confidence;

}

-(BOOL)_finishInit:(xadTAGPTR)tags error:(XADError *)error;
-(xadUINT32)_newEntryCallback:(struct xadProgressInfo *)info;

-(NSData *)_contentsOfFileInfo:(struct xadFileInfo *)info;

-(void)setProgressInterval:(NSTimeInterval)interval;
-(xadUINT32)_progressCallback:(struct xadProgressInfo *)info;

-(struct xadMasterBase *)xadMasterBase;
-(struct xadArchiveInfo *)xadArchiveInfo;
-(struct xadFileInfo *)xadFileInfoForEntry:(int)n;


@end
