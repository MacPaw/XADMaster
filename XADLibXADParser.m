#import "XADLibXADParser.h"
#import "CSMultiHandle.h"


static xadUINT32 ProgressFunc(struct Hook *hook,xadPTR object,struct xadProgressInfo *info);
static xadUINT32 InFunc(struct Hook *hook,xadPTR object,struct xadHookParam *param);



@implementation XADLibXADParser

+(int)requiredHeaderSize
{
	return 0;
}

+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name
{
	return NO;
}

-(id)initWithHandle:(CSHandle *)handle name:(NSString *)name
{
	if(self=[super initWithHandle:handle name:name])
	{
		xmb=NULL;
		archive=NULL;

		namedata=[[[self name] dataUsingEncoding:NSUTF8StringEncoding] mutableCopy];
		[namedata increaseLengthBy:1];

		if(xmb=xadOpenLibrary(12))
		{
			if(archive=xadAllocObjectA(xmb,XADOBJ_ARCHIVEINFO,NULL))
			{
				inhook.h_Entry=InFunc;
				inhook.h_Data=(void *)self;
				progresshook.h_Entry=ProgressFunc;
				progresshook.h_Data=(void *)self;

				return self;
			}
		}
		[self release];
	}
	return nil;
}

-(void)dealloc
{
	xadFreeInfo(xmb,archive); // check?
	xadFreeObjectA(xmb,archive,NULL);

	[namedata release];

	[super dealloc];
}

-(char *)encodedName { return [namedata mutableBytes]; }

-(void)parse
{
	addonbuild=YES;
	numadded=0;

	struct TagItem tags[]={
		XAD_INHOOK,(xadUINT32)&inhook,
		XAD_PROGRESSHOOK,(xadUINT32)&progresshook,
	TAG_DONE};

	int err=xadGetInfoA(xmb,archive,tags);
	if(!err&&archive->xai_DiskInfo)
	{
		xadFreeInfo(xmb,archive);
		err=xadGetDiskInfo(xmb,archive,XAD_INDISKARCHIVE,tags,TAG_DONE);
	}
	else if(err==XADERR_FILETYPE) err=xadGetDiskInfoA(xmb,archive,tags);

	if(err) [XADException raiseExceptionWithXADError:err];

/*	if(![fileinfos count])
	{
		if(error) *error=XADERR_DATAFORMAT;
		return NO;
	}*/

	if(!addonbuild) // encountered entries which could not be immediately added
	{
		struct xadFileInfo *info=archive->xai_FileInfo;

		for(int i=0;i<numadded&&info;i++) info=info->xfi_Next;

		while(info)
		{
			[self addEntryWithDictionary:[self dictionaryForFileInfo:info]];
			info=info->xfi_Next;
		}
	}
}

static xadUINT32 InFunc(struct Hook *hook,xadPTR object,struct xadHookParam *param)
{
	struct xadArchiveInfo *archive=object;
	XADLibXADParser *parser=(XADLibXADParser *)hook->h_Data;

	CSHandle *fh=[parser handle];

	switch(param->xhp_Command)
	{
		case XADHC_INIT:
		{
			if([fh respondsToSelector:@selector(handles)])
			{
				NSArray *handles=[(id)fh handles];
				int count=[handles count];

				archive->xai_MultiVolume=calloc(sizeof(xadSize),count+1);

				off_t total=0;
				for(int i=0;i<count;i++)
				{
					archive->xai_MultiVolume[i]=total;
					total+=[[handles objectAtIndex:i] fileSize];
				}
			}

			archive->xai_InName=[parser encodedName];

			return XADERR_OK;
		}

		case XADHC_SEEK:
			[fh skipBytes:param->xhp_CommandData];
			param->xhp_DataPos=[fh offsetInFile];
			return XADERR_OK;

		case XADHC_READ:
			[fh readBytes:param->xhp_BufferSize toBuffer:param->xhp_BufferPtr];
			param->xhp_DataPos=[fh offsetInFile];
			return XADERR_OK;

		case XADHC_FULLSIZE:
			@try {
				param->xhp_CommandData=[fh fileSize];
			} @catch(id e) { return XADERR_NOTSUPPORTED; }
			return XADERR_OK;

		case XADHC_FREE:
			free(archive->xai_MultiVolume);
			archive->xai_MultiVolume=NULL;
			return XADERR_OK;

 		default:
			return XADERR_NOTSUPPORTED;
	}
}

static xadUINT32 ProgressFunc(struct Hook *hook,xadPTR object,struct xadProgressInfo *info)
{
	XADLibXADParser *parser=(XADLibXADParser *)hook->h_Data;

	//id delegate=[archive delegate];
	//if(delegate&&[delegate archiveExtractionShouldStop:archive]) return 0;

	switch(info->xpi_Mode)
	{
		case XADPMODE_PROGRESS:
			//return [archive _progressCallback:info];
			return XADPIF_OK;

		case XADPMODE_NEWENTRY:
			[parser newEntryCallback:info];
			return XADPIF_OK;

		case XADPMODE_END:
		case XADPMODE_ERROR:
		case XADPMODE_GETINFOEND:
		default:
		break;
	}

	return XADPIF_OK;
}

-(void)newEntryCallback:(struct xadProgressInfo *)proginfo
{
	struct xadFileInfo *info=proginfo->xpi_FileInfo;
	if(addonbuild)
	{
		if(!(info->xfi_Flags&XADFIF_EXTRACTONBUILD)
		||(info->xfi_Flags&XADFIF_ENTRYMAYCHANGE))
		{
			addonbuild=NO;
		}
		else
		{
			[self addEntryWithDictionary:[self dictionaryForFileInfo:info]];
			numadded++;
		}
	}
}

-(NSMutableDictionary *)dictionaryForFileInfo:(struct xadFileInfo *)info
{
	NSMutableDictionary *dict=[NSMutableDictionary dictionaryWithObjectsAndKeys:
		[self XADStringWithCString:info->xfi_FileName],XADFileNameKey,
		[NSNumber numberWithUnsignedLongLong:info->xfi_CrunchSize],XADCompressedSizeKey,
		[NSValue valueWithPointer:info],@"LibXADFileInfo",
	nil];

	if(!(info->xfi_Flags&XADFIF_NOUNCRUNCHSIZE))
	[dict setObject:[NSNumber numberWithUnsignedLongLong:info->xfi_Size] forKey:XADFileSizeKey];

	if(!(info->xfi_Flags&XADFIF_NODATE))
	{
		xadUINT32 timestamp;
		xadConvertDates(xmb,XAD_DATEXADDATE,&info->xfi_Date,XAD_GETDATEUNIX,&timestamp,TAG_DONE);

		[dict setObject:[NSDate dateWithTimeIntervalSince1970:timestamp] forKey:XADLastModificationDateKey];
	}

	//if(info->xfi_Flags&XADFIF_NOFILENAME)
	// TODO: set no filename flag

	if(info->xfi_Flags&XADFIF_UNIXPROTECTION)
	[dict setObject:[NSNumber numberWithInt:info->xfi_UnixProtect] forKey:XADPosixPermissionsKey];

	if(info->xfi_Flags&XADFIF_DIRECTORY)
	[dict setObject:[NSNumber numberWithBool:YES] forKey:XADIsDirectoryKey];

	if(info->xfi_Flags&XADFIF_LINK)
	[dict setObject:[self XADStringWithCString:info->xfi_LinkName] forKey:XADLinkDestinationKey];

	if(info->xfi_Flags&XADFIF_CRYPTED)
	[dict setObject:[NSNumber numberWithBool:YES] forKey:XADIsEncryptedKey];

//	if(info->xfi_Flags&XADFIF_PARTIALFILE) // TODO: figure out what this is
//	[dict setObject:[NSNumber numberWithBool:YES] forKey:XADIsPartialKey];

	if(info->xfi_OwnerUID)
	[dict setObject:[NSNumber numberWithInt:info->xfi_OwnerUID] forKey:XADPosixUserKey];

	if(info->xfi_OwnerGID)
	[dict setObject:[NSNumber numberWithInt:info->xfi_OwnerGID] forKey:XADPosixGroupKey];

	if(info->xfi_UserName)
	[dict setObject:[self XADStringWithCString:info->xfi_UserName] forKey:XADPosixUserNameKey];

	if(info->xfi_GroupName)
	[dict setObject:[self XADStringWithCString:info->xfi_GroupName] forKey:XADPosixGroupNameKey];

	if(info->xfi_Comment)
	[dict setObject:[self XADStringWithCString:info->xfi_Comment] forKey:XADCommentKey];

	if(archive->xai_Flags&XADAIF_FILECORRUPT) [self setObject:[NSNumber numberWithBool:YES] forPropertyKey:XADIsCorruptedKey];

	return dict;
}



-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)properties wantChecksum:(BOOL)checksum
{
	return nil;
}

/*-(xadERROR)_extractFileInfo:(struct xadFileInfo *)info tags:(xadTAGPTR)tags reportProgress:(BOOL)report
{
	const char *pass=[self _encodedPassword];
	return xadFileUnArc(xmb,archive,
		XAD_ENTRYNUMBER,info->xfi_EntryNumber,
		report?XAD_PROGRESSHOOK:TAG_IGNORE,&progresshook,
		pass?XAD_PASSWORD:TAG_IGNORE,pass,
		TAG_MORE,tags,
	TAG_DONE);
}*/

-(NSString *)formatName
{
	NSString *format=[[[NSString alloc] initWithBytes:archive->xai_Client->xc_ArchiverName
	length:strlen(archive->xai_Client->xc_ArchiverName) encoding:NSISOLatin1StringEncoding] autorelease];
	/*if(parentarchive) return [NSString stringWithFormat:@"%@ in %@",format,[parentarchive formatName]];
	else*/ return format;
}



/*
@implementation XADLibXADHandle

-(id)initWith
{
}

-(void)dealloc
{
}

-(void)resetStream
{
	[parser stopExtracting];
	[parser startExtractingFromEntry:dict];
}

-(int)streamAtMost:(int)num toBuffer:(void *)buffer
{
	return [parser extractDataToBuffer:buffer length:num];
}

@end
*/

/*
-(NSData *)_contentsOfFileInfo:(struct xadFileInfo *)info
{
	if(info->xfi_Flags&XADFIF_NOUNCRUNCHSIZE) return nil;

	xadSize size=info->xfi_Size;
	void *buffer=malloc(size);

	if(buffer)
	{
		struct TagItem tags[]={
			XAD_OUTMEMORY,(xadPTRINT)buffer,
			XAD_OUTSIZE,size,
		TAG_DONE};

		int err=[self _extractFileInfo:info tags:tags reportProgress:NO];

		if(!err) return [NSData dataWithBytesNoCopy:buffer length:size freeWhenDone:YES];

		lasterror=err;
		free(buffer);
	}
	else lasterror=XADERR_NOMEMORY;

	return nil;
}


-(xadUINT32)_progressCallback:(struct xadProgressInfo *)info
{
	struct timeval tv;
	gettimeofday(&tv,NULL);
	double currtime=(double)tv.tv_sec+(double)tv.tv_usec/1000000.0;

	if(currtime-update_time<update_interval) return XADPIF_OK;
	update_time=currtime;

	int progress,filesize;
	if(info->xpi_FileInfo->xfi_Flags&XADFIF_NOUNCRUNCHSIZE)
	{
		progress=archive->xai_InPos-info->xpi_FileInfo->xfi_DataPos;
		filesize=info->xpi_FileInfo->xfi_CrunchSize;
	}
	else
	{
		progress=info->xpi_CurrentSize;
		filesize=info->xpi_FileInfo->xfi_Size;
	}

	[delegate archive:self extractionProgressForEntry:currentry bytes:progress of:filesize];

	if(totalsize)
	[delegate archive:self extractionProgressBytes:extractsize+progress of:totalsize];

	return XADPIF_OK;
}



-(struct xadMasterBase *)xadMasterBase { return xmb; }

-(struct xadArchiveInfo *)xadArchiveInfo { return archive; }

-(struct xadFileInfo *)xadFileInfoForEntry:(int)n { return (struct xadFileInfo *)[[fileinfos objectAtIndex:n] pointerValue]; }
*/
@end




