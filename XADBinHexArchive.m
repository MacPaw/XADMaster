#import "XADBinHexArchive.h"

static inline xadUINT16 binhex_update_crc(xadUINT16 crc,xadUINT8 val)
{
	return (crc<<8)^xadCRC_1021_crctable[(crc>>8)^val];
}



@interface XADBinHexHandle:CSHandle
{
}

@end



@implementation XADBinHexArchive

+(int)requiredHeaderSize { return 4096; }

+(BOOL)canOpenFile:(NSString *)filename handle:(CSHandle *)handle firstBytes:(NSData *)data
{
	int length=[data length]
	const void *data=[data bytes];
	if(length>=45&&!memcmp("(This file must be converted with BinHex 4.0)",data,45)) return YES;

	XADBinHexHandle *handle=[[[XADBinHexHandle alloc] initWithHandle:handle] autorelease]; // copy?
	uint16_t crc=0;

	uint8_t len=[handle readUInt8];
	if(len<1||len>63) return NO;
	crc=binhex_update_crc(crc,len);

	// Scan name to make sure there are no null bytes
	for(int i=0;i<len;i++)
	{
		uint8_t chr=[handle readUInt8];
		if(chr==0) return NO;
		crc=binhex_update_crc(crc,chr);
	}

	// Read rest of header
	for(int i=0;i<19;i++)
	{
		uint8_t chr=[handle readUInt8];
		crc=binhex_update_crc(crc,chr);
	}

	// Check CRC
	uint16_t realcrc=[handle readUInt16BE];
	if(realcrc!=crc) return NO;

	return YES;
}

-(id)initWithFile:(NSString *)filename handle:(CSHandle *)handle
{
}

-(void)scan
{
	XADBinHexHandle *handle=[[[XADBinHexHandle alloc] initWithHandle:handle] autorelease]; // copy?

	uint8_t namelen=[handle readUInt8];
	if(namelen>63) @throw [XADException dataFormatException];
	uint8_t namebuf[64];
	[handle readBytes:namelen toBuffer:namebuf];
	namebuf[namelen]=0;

	[handle skipBytes:1];
	uint32 type=[handle readUInt32BE];
	uint32 creator=[handle readUInt32BE];
	uint16 flags=[handle readUInt16BE];
	uint32 datalen=[handle readUInt32BE];
	uint32 rsrclen=[handle readUInt32BE];
	uint16 crc=[handle readUInt16BE];

/*	printf("file:%s version:%d flags:%x datalen:%d rsrclen:%d %c%c%c%c %c%c%c%c\n",
	namebuf,version,flags,datalen,rsrclen,headbuf[1],headbuf[2],headbuf[3],headbuf[4],
	headbuf[5],headbuf[6],headbuf[7],headbuf[8]);*/

	[self addEntry:[NSDictionary dictionaryWithObjectsAndKeys:
		XADFileNameKey,[self xadStringWithBytes:namebuf length:namelen encoding:NSMacOSRomanStringEncoding],
		XADFileSizeKey,[NSNumber numberWithUnsignedInt:datalen],
		XADFileCompressedSizeKey,[NSNumber numberWithUnsignedInt:(datalen*4)/3],
		XADFileOffsetKey,[NSNumber numberWithUnsignedInt:22+namelen],
		XADFileTypeKey,[NSNumber numberWithUnsignedInt:type],
		XADFileCreatorKey,[NSNumber numberWithUnsignedInt:creator],
		XADFinderFlagsKey,[NSNumber numberWithUnsignedShort:flags],
		XADResourceSizeKey,[NSNumber numberWithUnsignedInt:rsrclen],
		XADResourceCompressedSizeKey,[NSNumber numberWithUnsignedInt:(rsrclen*4)/3],
		XADResourceOffsetKey,[NSNumber numberWithUnsignedInt:24+namelen+datalen],
		XADCanExtractOnBuildKey,[NSNumber numberWithBool:YES],
	nil]];
}

-(CSHandle *)handleForEntryWithProperties:(NSDictionary *)properties
{
	struct xadFileInfo *fi=ai->xai_CurFile;
	xadERROR err=XADERR_OK;
	xadUINT16 crc=0;
	xadUINT8 *buf=BINHEXPAI(ai)->buf,realcrc[2];
	xadUINT32 bytesleft;

	if(err=binhex_seek(&BINHEXPAI(ai)->parser,(xadUINT32)fi->xfi_DataPos)) return err;

	bytesleft=(xadUINT32)fi->xfi_Size;
	while(bytesleft)
	{
		xadUINT32 readbytes=BINHEX_BUFSIZE;
		if(readbytes>bytesleft) readbytes=bytesleft;

		if(err=binhex_read_bytes(&BINHEXPAI(ai)->parser,readbytes,buf)) return err;
		if(err=xadHookTagAccess(XADM XADAC_WRITE,readbytes,buf,ai,
//			XAD_CRC16ID,0x1021,
//			XAD_GETCRC16,&crc,
		TAG_DONE)) return err;

		for(int i=0;i<readbytes;i++) crc=binhex_update_crc(crc,buf[i]);

		bytesleft-=readbytes;
	}

	if(err=binhex_read_bytes(&BINHEXPAI(ai)->parser,2,realcrc)) return err;
	if(crc!=EndGetM16(realcrc)) return XADERR_CHECKSUM;

	return XADERR_OK;
}

-(CSHandle *)resourceHandleEntryWithProperties:(NSDictionary *)properties
{
}

-(NSString *)formatName { return @"BinHex"; }

@end

@implementation XADBinHexHandle

	xadSize start_xadpos;

	const xadUINT8 *mem_buf;
	xadUINT32 mem_size,mem_pos;

	int state;
	xadUINT8 prev_bits;
	xadUINT8 rle_byte,rle_num;
	xadUINT32 pos;
	xadERROR err;

	struct binhex_parser parser;
	xadUINT8 buf[BINHEX_BUFSIZE];

#define BINHEX_BUFSIZE 16384
#define BINHEX_HEX_DIGIT(a) (((a)<=9)?((a)+'0'):((a)-10+'A'))

	// Scan for start-of-data ':' marker
	char prev='\n',curr;
	for(;;)
	{
		if(err=xadHookAccess(XADM XADAC_READ,1,&curr,ai)) return err;
		if(curr==':'&&(prev=='\n'||prev=='\r')) break;
		prev=curr;
	}

static void binhex_setup_hook_parser(struct binhex_parser *parser,struct xadArchiveInfo *ai,struct xadMasterBase *xmb)
{
	parser->ai=ai;
	parser->xmb=xmb;
	parser->start_xadpos=ai->xai_InPos;
	parser->mem_buf=NULL;
	parser->mem_size=0;
	parser->mem_pos=0;
	parser->state=0;
	parser->rle_byte=0;
	parser->rle_num=0;
	parser->pos=0;
	parser->err=XADERR_OK;
}

static void binhex_setup_mem_parser(struct binhex_parser *parser,const xadPTR buf,xadUINT32 size)
{
	parser->ai=NULL;
	parser->xmb=NULL;
	parser->start_xadpos=0;
	parser->mem_buf=buf;
	parser->mem_size=size;
	parser->mem_pos=0;
	parser->state=0;
	parser->rle_byte=0;
	parser->rle_num=0;
	parser->pos=0;
	parser->err=XADERR_OK;
}

static xadUINT8 binhex_get_bits(struct binhex_parser *parser)
{
	xadUINT8 *codes=(xadUINT8 *)"!\"#$%&'()*+,-012345689@ABCDEFGHIJKLMNPQRSTUVXYZ[`abcdefhijklmpqr";

	if(parser->err) return 0;
	for(;;)
	{
		xadUINT8 byte;
		if(parser->ai)
		{
			if(parser->err=xadHookAccess(parser->xmb,XADAC_READ,1,&byte,parser->ai)) return 0;
		}
		else if(parser->mem_buf)
		{
			if(parser->mem_pos>=parser->mem_size) { parser->err=XADERR_INPUT; return 0; }
			else byte=parser->mem_buf[parser->mem_pos++];
		}
		if(byte==':') { parser->err=XADERR_INPUT; return 0; }
		for(xadUINT8 bits=0;bits<64;bits++) if(byte==codes[bits]) return bits;
	}
}

static xadUINT8 binhex_decode_byte(struct binhex_parser *parser)
{
	xadUINT8 bits1,bits2,res;

	switch(parser->state)
	{
		case 0:
			bits1=binhex_get_bits(parser);
			bits2=binhex_get_bits(parser);
			parser->prev_bits=bits2;
			res=(bits1<<2)|(bits2>>4);
			parser->state=1;
		break;

		case 1:
			bits1=parser->prev_bits;
			bits2=binhex_get_bits(parser);
			parser->prev_bits=bits2;
			res=(bits1<<4)|(bits2>>2);
			parser->state=2;
		break;

		case 2:
			bits1=parser->prev_bits;
			bits2=binhex_get_bits(parser);
			res=(bits1<<6)|bits2;
			parser->state=0;
		break;
	}

	return res;
}

static xadERROR binhex_read_bytes(struct binhex_parser *parser,xadUINT32 bytes,xadUINT8 *buf)
{
	for(xadUINT32 i=0;i<bytes;i++)
	{
		if(parser->rle_num)
		{
			if(buf) buf[i]=parser->rle_byte;
			parser->rle_num--;
		}
		else
		{
			xadUINT8 byte=binhex_decode_byte(parser);
			if(parser->err) return parser->err;

			if(byte!=0x90)
			{
				if(buf) buf[i]=byte;
				parser->rle_byte=byte;
			}
			else
			{
				xadUINT8 count=binhex_decode_byte(parser);
				if(parser->err) return parser->err;

				if(count==0)
				{
					if(buf) buf[i]=0x90;
					parser->rle_byte=0x90;
				}
				else if(count>=2)
				{
					if(buf) buf[i]=parser->rle_byte;
					parser->rle_num=count-2;
				}
			}
		}
	}

	parser->pos+=bytes;

	return XADERR_OK;
}

static xadERROR binhex_seek(struct binhex_parser *parser,xadUINT32 newpos)
{
	if(newpos<parser->pos)
	{
		if(parser->ai)
		{
			if(parser->err=xadHookAccess(parser->xmb,XADAC_INPUTSEEK,
			parser->start_xadpos-parser->ai->xai_InPos,NULL,parser->ai)) return parser->err;
		}
		else if(parser->mem_buf) parser->mem_pos=0;

		parser->state=0;
		parser->rle_byte=0;
		parser->rle_num=0;
		parser->pos=0;
	}

	return binhex_read_bytes(parser,newpos-parser->pos,NULL);
}

