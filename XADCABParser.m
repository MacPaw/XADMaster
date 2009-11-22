#import "XADCABParser.h"
#import "XADMSLZXHandle.h"
#import "XADMSZipHandle.h"
#import "XADQuantumHandle.h"
#import "XADCRCHandle.h"
#import "NSDateXAD.h"
#import "CSFileHandle.h"
#import "CSMultiHandle.h"

#include <dirent.h>



typedef struct CABHeader
{
	off_t cabsize;
	off_t fileoffs;
	int minorversion,majorversion;
	int numfolders,numfiles;
	int flags;
	int setid,cabindex;

	int headerextsize,folderextsize,datablockextsize;

	NSData *nextvolume,*prevvolume;
} CABHeader;

static CABHeader ReadCABHeader(CSHandle *fh);
static void SkipCString(CSHandle *fh);
static NSData *ReadCString(CSHandle *fh);
static CSHandle *FindHandleForName(NSData *namedata,NSString *dirname);



@implementation XADCABParser

+(int)requiredHeaderSize { return 4; }

+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name
{
	const uint8_t *bytes=[data bytes];
	int length=[data length];

	return length>=4&&bytes[0]=='M'&&bytes[1]=='S'&&bytes[2]=='C'&&bytes[3]=='F';
}

+(NSArray *)volumesForFilename:(NSString *)filename
{
	NSArray *res=nil;
	@try
	{
		NSString *dirname=[filename stringByDeletingLastPathComponent];
		NSMutableArray *volumes=[NSMutableArray arrayWithObject:filename];
		NSString *volumename;

		CSHandle *fh=[CSFileHandle fileHandleForReadingAtPath:filename];
		CABHeader firsthead=ReadCABHeader(fh);

		NSData *namedata=firsthead.prevvolume;
		int lastindex=firsthead.cabindex;
		while(namedata)
		{
			NSAutoreleasePool *pool=[NSAutoreleasePool new];

			CSHandle *fh=FindHandleForName(namedata,dirname);
			[volumes insertObject:[fh name] atIndex:0];
			CABHeader head=ReadCABHeader(fh);
			if(head.cabindex!=lastindex-1) @throw @"Index mismatch";

			namedata=[head.prevvolume retain];
			lastindex=head.cabindex;
			[pool release];
			[namedata autorelease];
		}

		if(lastindex!=0) @throw @"Couldn't find first volume";
		res=volumes;

		namedata=firsthead.nextvolume;
		lastindex=firsthead.cabindex;
		while(namedata)
		{
			NSAutoreleasePool *pool=[NSAutoreleasePool new];

			CSHandle *fh=FindHandleForName(namedata,dirname);
			[volumes addObject:[fh name]];
			CABHeader head=ReadCABHeader(fh);
			if(head.cabindex!=lastindex+1) @throw @"Index mismatch";

			namedata=[head.nextvolume retain];
			lastindex=head.cabindex;
			[pool release];
			[namedata autorelease];
		}
	}
	@catch(id e) { NSLog(@"CAB volume scanning error: %@",e); }

	return res;
}



-(void)parse
{
	CSHandle *fh=[self handle];

	off_t baseoffs=[fh offsetInFile];

	NSMutableArray *continuedfolder=nil;
	for(;;)
	{
		CABHeader head=ReadCABHeader(fh);

		NSMutableArray *folders=[NSMutableArray array];
		for(int i=0;i<head.numfolders;i++)
		{
			uint32_t dataoffs=[fh readUInt32LE];
			int numblocks=[fh readUInt16LE];
			int method=[fh readUInt16LE];
			[fh skipBytes:head.folderextsize];

			NSDictionary *folderpart=[NSDictionary dictionaryWithObjectsAndKeys:
				[NSNumber numberWithLongLong:baseoffs+dataoffs],@"Offset",
				[NSNumber numberWithInt:numblocks],@"NumberOfBlocks",
				[NSNumber numberWithInt:method],@"Method",
			nil];

			NSMutableArray *folder;
			if(continuedfolder)
			{
				if(method!=[[[continuedfolder objectAtIndex:0] objectForKey:@"Method"] intValue]) [XADException raiseIllegalDataException];
				[continuedfolder addObject:folderpart];
				folder=continuedfolder;
				continuedfolder=nil;
			}
			else
			{
				folder=[NSMutableArray arrayWithObject:folderpart];
			}

			[folders addObject:folder];
		}

		[fh seekToFileOffset:baseoffs+head.fileoffs];

		for(int i=0;i<head.numfiles;i++)
		{
			uint32_t filesize=[fh readUInt32LE];
			uint32_t folderoffs=[fh readUInt32LE];
			int folderindex=[fh readUInt16LE];
			int date=[fh readUInt16LE];
			int time=[fh readUInt16LE];
			int attribs=[fh readUInt16LE];
			NSData *namedata=ReadCString(fh);

			if(folderindex==0xffff||folderindex==0xfffe)
			{
				folderindex=head.numfolders-1;
				continuedfolder=[folders objectAtIndex:folderindex];
				NSLog(@"cont");
			}
			else if(folderindex==0xfffd)
			{
				folderindex=0;
			}
			
			if(folderindex>=head.numfolders) [XADException raiseIllegalDataException];
			NSArray *folder=[folders objectAtIndex:folderindex];

			XADPath *name;
			if(attribs&0x80) name=[self XADPathWithData:namedata encoding:NSUTF8StringEncoding separators:XADWindowsPathSeparator];
			else name=[self XADPathWithData:namedata separators:XADWindowsPathSeparator];

			NSMutableDictionary *dict=[NSMutableDictionary dictionaryWithObjectsAndKeys:
				name,XADFileNameKey,
				[NSNumber numberWithUnsignedInt:filesize],XADFileSizeKey,
				[NSDate XADDateWithMSDOSDate:date time:time],XADLastModificationDateKey,
				[NSNumber numberWithUnsignedInt:folderoffs],XADSolidOffsetKey,
				[NSNumber numberWithUnsignedInt:filesize],XADSolidLengthKey,
				folder,XADSolidObjectKey,
			nil];

			int method=[[[folder objectAtIndex:0] objectForKey:@"Method"] intValue];
			NSString *methodname=nil;
			switch(method)
			{
				case 0: methodname=@"None"; break;
				case 1: methodname=@"MSZIP"; break;
				case 2: methodname=@"Quantum"; break;
				case 0x0f03: methodname=@"LZX:15"; break;
				case 0x1003: methodname=@"LZX:16"; break;
				case 0x1103: methodname=@"LZX:17"; break;
				case 0x1203: methodname=@"LZX:18"; break;
				case 0x1303: methodname=@"LZX:19"; break;
				case 0x1403: methodname=@"LZX:20"; break;
				case 0x1503: methodname=@"LZX:21"; break;
			}
			if(methodname) [dict setObject:[self XADStringWithString:methodname] forKey:XADCompressionNameKey];

			[self addEntryWithDictionary:dict retainPosition:YES];
		}

		if([fh respondsToSelector:@selector(currentHandle)])
		{
			[[(id)fh currentHandle] seekToEndOfFile];
			if([fh atEndOfFile]) break;
			baseoffs=[fh offsetInFile];
		}
		else break;
	}
}

-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum
{
/*	CSHandle *handle=[self subHandleFromSolidStreamForEntryWithDictionary:dict];

	if(checksum) handle=[XADCRCHandle IEEECRC32HandleWithHandle:handle length:[handle fileSize]
	correctCRC:[[dict objectForKey:@"LZXCRC32"] unsignedIntValue] conditioned:YES];

	return handle;*/
	return nil;
}

-(CSHandle *)handleForSolidStreamWithObject:(id)obj wantChecksum:(BOOL)checksum
{
/*	CSHandle *handle=[self handleAtDataOffsetForDictionary:obj];
	off_t length=[[obj objectForKey:@"TotalSize"] longLongValue];
	int method=[[obj objectForKey:@"Method"] intValue];

	switch(method)
	{
		case 0: return handle;
		case 2: return [[[XADLZXHandle alloc] initWithHandle:handle length:length] autorelease];
		default: return nil;
	}*/
	return nil;
}

-(NSString *)formatName { return @"CAB"; }

@end




@implementation XADCABSFXParser

+(int)requiredHeaderSize { return 65536; }

+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name
{
	const uint8_t *bytes=[data bytes];
	int length=[data length];

	if(length<20000||bytes[0]!='M'||bytes[1]!='Z') return NO;

	// From libxad:
	for(int i=8;i<=length+8;i++)
	{
		// word aligned code signature: 817C2404 "MSCF" (found at random, sorry)
		if((i&1)==0)
		if(bytes[i+0]==0x81 && bytes[i+1]==0x7c && bytes[i+2]==0x24 && bytes[i+3]==0x04 &&
		bytes[i+4]=='M' && bytes[i+5]=='S' && bytes[i+6]=='C' && bytes[i+7]=='F') return YES;

		// another revision: 7D817DDC "MSCF" (which might not be aligned)
		if(bytes[i+0]==0x7d && bytes[i+1]==0x81 && bytes[i+2]==0x7d && bytes[i+3]==0xdc &&
		bytes[i+4]=='M' && bytes[i+5]=='S' && bytes[i+6]=='C' && bytes[i+7]=='F') return YES;
	}

	return NO;
}

+(NSArray *)volumesForFilename:(NSString *)name { return nil; }

-(void)parse
{
	CSHandle *fh=[self handle];
	off_t remainingsize=[fh fileSize];

	uint8_t buf[20];
	[fh readBytes:sizeof(buf) toBuffer:buf];

	for(;;)
	{
		if(buf[0]=='M'&&buf[1]=='S'&&buf[2]=='C'&&buf[3]=='F')
		{
			uint32_t len=CSUInt32LE(&buf[8]);
			uint32_t offs=CSUInt32LE(&buf[16]);
			if(len<=remainingsize&&offs<len) break;
		}

		memmove(buf,buf+1,sizeof(buf)-1);
		if([fh readAtMost:1 toBuffer:&buf[sizeof(buf)-1]]==0) return;

		remainingsize--;
	}

	[fh skipBytes:-sizeof(buf)];
	[super parse];
}

-(NSString *)formatName { return @"Self-extracting CAB"; }

@end



static CABHeader ReadCABHeader(CSHandle *fh)
{
	CABHeader head;

	uint32_t signature=[fh readUInt32BE];
	if(signature!='MSCF') [XADException raiseIllegalDataException];

	[fh skipBytes:4];
	head.cabsize=[fh readUInt32LE];
	[fh skipBytes:4];
	head.fileoffs=[fh readUInt32LE];
	[fh skipBytes:4];
	head.minorversion=[fh readUInt8];
	head.majorversion=[fh readUInt8];
	head.numfolders=[fh readUInt16LE];
	head.numfiles=[fh readUInt16LE];
	head.flags=[fh readUInt16LE];
	head.setid=[fh readUInt16LE];
	head.cabindex=[fh readUInt16LE];

	if(head.flags&4) // extended data present
	{
		head.headerextsize=[fh readUInt16LE];
		head.folderextsize=[fh readUInt8];
		head.datablockextsize=[fh readUInt8];
		[fh skipBytes:head.headerextsize];
	}
	else head.headerextsize=head.folderextsize=head.datablockextsize=0;

	if(head.flags&1)
	{
		head.prevvolume=ReadCString(fh);
		SkipCString(fh);
	}
	else head.prevvolume=nil;

	if(head.flags&2)
	{
		head.nextvolume=ReadCString(fh);
		SkipCString(fh);
	}
	else head.nextvolume=nil;

	return head;
}

static void SkipCString(CSHandle *fh)
{
	while([fh readUInt8]);
}

static NSData *ReadCString(CSHandle *fh)
{
	NSMutableData *data=[NSMutableData data];
	uint8_t b;
	while(b=[fh readUInt8]) [data appendBytes:&b length:1];
	return data;
}

static CSHandle *FindHandleForName(NSData *namedata,NSString *dirname)
{
	NSString *filepart=[[[NSString alloc] initWithData:namedata encoding:NSWindowsCP1252StringEncoding] autorelease];
	NSString *volumename=[dirname stringByAppendingPathComponent:filepart];

	@try
	{
		CSHandle *handle=[CSFileHandle fileHandleForReadingAtPath:volumename];
		if(handle) return handle;
	}
	@catch(id e) { }

	NSMutableArray *volumes=[NSMutableArray array];

	if(!dirname||[dirname length]==0) dirname=@".";
	DIR *dir=opendir([dirname fileSystemRepresentation]);
	if(!dir) return nil;

	struct dirent *ent;
	while(ent=readdir(dir))
	{
		int len=strlen(ent->d_name);
		if(len==[namedata length]&&strncasecmp([namedata bytes],ent->d_name,len)==0)
		{
			NSString *filename=[dirname stringByAppendingPathComponent:[NSString stringWithUTF8String:ent->d_name]];
			@try
			{
				CSHandle *handle=[CSFileHandle fileHandleForReadingAtPath:filename];
				if(handle)
				{
					closedir(dir);
					return handle;
				}
			}
			@catch(id e) { }
		}
	}

	closedir(dir);

	return nil;
}
