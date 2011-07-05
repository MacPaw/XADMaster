#import "XADSWFParser.h"
#import "SWFParser.h"
#import "CSMemoryHandle.h"
#import "CSMultiHandle.h"

@implementation XADSWFParser

+(int)requiredHeaderSize { return 6; }

+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name
{
	const uint8_t *bytes=[data bytes];
	int length=[data length];

	if(length<4) return NO;

	NSLog(@"SWF version %d\n",bytes[3]);

	if(bytes[0]=='F'&&bytes[1]=='W'&&bytes[2]=='S') return YES;
	if(bytes[0]=='C'&&bytes[1]=='W'&&bytes[2]=='S') return YES;

	return YES;
}

-(id)initWithHandle:(CSHandle *)handle name:(NSString *)name
{
	if((self=[super initWithHandle:handle name:name]))
	{
		parser=[[SWFParser parserWithHandle:handle] retain];
		dataobjects=[NSMutableArray new];
	}
	return self;
}

-(void)dealloc
{
	[parser release];
	[dataobjects release];
	[super dealloc];
}

-(void)parse
{
	[parser parseHeader];

	CSHandle *fh=[parser handle];

	int numimages=0;
	int numsounds=0;
	int numstreams=0;
	int laststreamframe=-1;
	NSData *currjpegtables=nil;
	NSMutableData *currstream=nil;

	NSString *compname;
	if([parser isCompressed]) compname=@"Zlib";
	else compname=@"None";

	int tag;
	while((tag=[parser nextTag]) && [self shouldKeepParsing])
	switch(tag)
	{
		case SWFJPEGTables:
		{
			currjpegtables=[fh readDataOfLength:[parser tagLength]-2];
			[dataobjects addObject:currjpegtables];
		}
		break;

		case SWFDefineBitsJPEGTag:
		{
			numimages++;

			[fh skipBytes:4];
			off_t offset=[fh offsetInFile];
			off_t length=[parser tagBytesLeft];

			if(!currjpegtables) [XADException raiseIllegalDataException];

			[self addEntryWithName:[NSString stringWithFormat:
			@"Image %d at frame %d.jpg",numimages,[parser frame]]
			data:currjpegtables offset:offset length:length];
		}
		break;

		case SWFDefineBitsJPEG2Tag:
		case SWFDefineBitsJPEG3Tag:
		{
			numimages++;

			[fh skipBytes:2];

			int alphaoffs=0;
			if(tag==SWFDefineBitsJPEG3Tag) alphaoffs=[fh readUInt32LE];
//if(alphaoffs!=0) NSLog(@"alphaoffs: %d",alphaoffs);

			int first=[fh readUInt16BE];
			if(first==0x8950)
			{
				// PNG image.
				[self addEntryWithName:[NSString stringWithFormat:
				@"Image %d at frame %d.png",numimages,[parser frame]]
				data:[NSData dataWithBytes:(uint8_t[2]){ 0x89,0x50 } length:2]
				offset:[fh offsetInFile] length:[parser tagBytesLeft]];
			}
			else if(first==0x4749)
			{
				// GIF image.
				[self addEntryWithName:[NSString stringWithFormat:
				@"Image %d at frame %d.gif",numimages,[parser frame]]
				data:[NSData dataWithBytes:(uint8_t[2]){ 0x47,0x49 } length:2]
				offset:[fh offsetInFile] length:[parser tagBytesLeft]];
			}
			else if(first==0xffd9)
			{
				// JPEG image with invalid EOI/SOI header. Skip the rest of
				// the header and use the rest of the file as is.
				[fh skipBytes:2];

				[self addEntryWithName:[NSString stringWithFormat:
				@"Image %d at frame %d.jpg",numimages,[parser frame]]
				offset:[fh offsetInFile] length:[parser tagBytesLeft]];
			}
			else if(first==0xffd8)
			{
				// JPEG image correct header. However, there may still be
				// a garbage EOI/SOI marker pair before the SOF, so we have
				// to parse and store all markers up until that.
				CSMemoryHandle *tables=[CSMemoryHandle memoryHandleForWriting];
				[tables writeUInt16BE:first];
				for(;;)
				{
					int marker=[fh readUInt16BE];
					if(marker==0xffd9||marker==0xffda)
					{
						// Skip garbage EOI/SOI pair if it exists.
						if(marker==0xffd9) [fh skipBytes:2];
						else [tables writeUInt16BE:marker];

						[self addEntryWithName:[NSString stringWithFormat:
						@"Image %d at frame %d.jpg",numimages,[parser frame]]
						data:[tables data]
						offset:[fh offsetInFile] length:[parser tagBytesLeft]];

						break;
					}
					else
					{
						int len=[fh readUInt16BE];
						[tables writeUInt16BE:marker];
						[tables writeUInt16BE:len];
						for(int i=0;i<len-2;i++) [tables writeUInt8:[fh readUInt8]];
					}
				}
			}
			else NSLog(@"Error loading SWF file: invalid JPEG data in tag %d",[parser tag]);
		}
		break;

		case SWFDefineBitsJPEG4Tag:
			NSLog(@"DefineBitsJPEG4");
		break;

		case SWFDefineBitsLosslessTag:
		case SWFDefineBitsLossless2Tag:
		{
			numimages++;

			[fh skipBytes:2];
			int formatnum=[fh readUInt8];

			// off_t offset=[fh offsetInFile];
			// off_t length=[parser tagBytesLeft];

			[self addEntryWithName:[NSString stringWithFormat:
			@"Image %d at frame %d.tiff",numimages,[parser frame]]
			data:[NSData data]];

/*			switch(formatnum)
			{
				case 3:
					if(tag==SWFDefineBitsLosslessTag)
					[self addEntry:[[[XeeSWFLossless3Entry alloc] initWithHandle:
					[fh subHandleOfLength:[parser tagBytesLeft]]
					name:[NSString stringWithFormat:@"Image %d",n++]] autorelease]];
					else
					[self addEntry:[[[XeeSWFLossless3AlphaEntry alloc] initWithHandle:
					[fh subHandleOfLength:[parser tagBytesLeft]]
					name:[NSString stringWithFormat:@"Image %d",n++]] autorelease]];
				break;

				case 4:
					NSLog(@"Error loading SWF file: unsupported lossless format 4. Please send the author of this program the file, so he can add support for it.");
				break;

				case 5:
					if(tag==SWFDefineBitsLosslessTag)
					[self addEntry:[[[XeeSWFLossless5Entry alloc] initWithHandle:
					[fh subHandleOfLength:[parser tagBytesLeft]]
					name:[NSString stringWithFormat:@"Image %d",n++]] autorelease]];
					else
					[self addEntry:[[[XeeSWFLossless5AlphaEntry alloc] initWithHandle:
					[fh subHandleOfLength:[parser tagBytesLeft]]
					name:[NSString stringWithFormat:@"Image %d",n++]] autorelease]];
				break;

				default:
					NSLog(@"Error loading SWF file: unsupported lossless format %d",formatnum);
				break;
			}*/
		}
		break;

		case SWFDefineSoundTag:
		{
			numsounds++;

			[fh skipBytes:2];

			int flags=[fh readUInt8];
			int format=flags>>4;
			if(format==2)
			{
				// MP3 audio.
				[fh skipBytes:4];

				[self addEntryWithName:[NSString stringWithFormat:
				@"Sound %d at frame %d.mp3",numsounds,[parser frame]]
				offset:[fh offsetInFile] length:[parser tagBytesLeft]];
			}
			else if(format==0||format==3)
			{
				// Uncompresed audio. Assumes format 0 is little-endian.
				// Create a WAV header.

				//uint32_t numsamples=[fh readUInt32LE];
				[fh skipBytes:4];

				int samplerate,bitsperchannel,numchannels;

				switch((flags>>2)&0x03)
				{
					case 0: samplerate=5512; break; // 5.5125 kHz - what.
					case 1: samplerate=11025; break;
					case 2: samplerate=22050; break;
					case 3: samplerate=44100; break;
				}

				if(flags&0x02) bitsperchannel=16;
				else bitsperchannel=8;

				if(flags&0x01) numchannels=2;
				else numchannels=1;

				int length=[parser tagBytesLeft];

				uint8_t header[44]=
				{
					'R','I','F','F',0x00,0x00,0x00,0x00,
					'W','A','V','E','f','m','t',' ',0x10,0x00,0x00,0x00,
					0x01,0x00, 0x00,0x00, 0x00,0x00,0x00,0x00,
					0x00,0x00,0x00,0x00,  0x00,0x00, 0x00,0x00,
					'd','a','t','a',0x00,0x00,0x00,0x00,
				};

				CSSetUInt32LE(&header[4],36+length);
				CSSetUInt16LE(&header[22],numchannels);
				CSSetUInt32LE(&header[24],samplerate);
				CSSetUInt32LE(&header[28],samplerate*numchannels*bitsperchannel/8);
				CSSetUInt16LE(&header[32],numchannels*bitsperchannel/8);
				CSSetUInt16LE(&header[34],bitsperchannel);
				CSSetUInt32LE(&header[40],length);

				[self addEntryWithName:[NSString stringWithFormat:
				@"Sound %d at frame %d.wav",numsounds,[parser frame]]
				data:[NSData dataWithBytes:header length:sizeof(header)]
				offset:[fh offsetInFile] length:length];
			}
			else NSLog(@"Unsupported sound format %x",format);
		}
		break;

		case SWFSoundStreamHeadTag:
		case SWFSoundStreamHead2Tag:
		{
			int flags=[fh readUInt8];
			int format=(flags>>4)&0x0f;
			if(format==2||format==0) // MP3 format - why is 0 MP3? Who knows!
			{
				currstream=[NSMutableData data];
				[dataobjects addObject:currstream];
			}
			else NSLog(@"Unsupported stream format");
		}
		break;

		case SWFSoundStreamBlockTag:
		{
			if(laststreamframe!=[parser frame])
			{
				laststreamframe=[parser frame];
				[fh skipBytes:4];
			}
			[currstream appendData:[fh readDataOfLength:[parser tagBytesLeft]]];
		}
		break;

		case SWFDefineSpriteTag:
			//NSLog(@"DefineSprite");
		break;
	}

	if(currstream)
	{
		numstreams++;

		[self addEntryWithName:[NSString stringWithFormat:@"Stream %d.mp3",numstreams]
		data:currstream];
	}
}

-(void)addEntryWithName:(NSString *)name data:(NSData *)data
{
	NSUInteger index=[dataobjects indexOfObjectIdenticalTo:data];
	if(index==NSNotFound)
	{
		index=[dataobjects count];
		[dataobjects addObject:data];
	}

	NSMutableDictionary *dict=[NSMutableDictionary dictionaryWithObjectsAndKeys:
		[self XADPathWithString:name],XADFileNameKey,
		[NSNumber numberWithLongLong:[data length]],XADFileSizeKey,
		[self XADStringWithString:[parser isCompressed]?@"Zlib":@"None"],XADCompressionNameKey,
		[NSNumber numberWithInt:index],@"SWFDataIndex",
	nil];
	[self addEntryWithDictionary:dict];
}

-(void)addEntryWithName:(NSString *)name offset:(off_t)offset length:(off_t)length
{
	NSMutableDictionary *dict=[NSMutableDictionary dictionaryWithObjectsAndKeys:
		[self XADPathWithString:name],XADFileNameKey,
		[NSNumber numberWithUnsignedLong:length],XADFileSizeKey,
		[NSNumber numberWithUnsignedLong:length],@"SWFDataLengthKey",
		[NSNumber numberWithUnsignedLong:offset],@"SWFDataOffsetKey",
		[self XADStringWithString:[parser isCompressed]?@"Zlib":@"None"],XADCompressionNameKey,
	nil];
	[self addEntryWithDictionary:dict];
}

-(void)addEntryWithName:(NSString *)name data:(NSData *)data offset:(off_t)offset length:(off_t)length
{
	NSUInteger index=[dataobjects indexOfObjectIdenticalTo:data];
	if(index==NSNotFound)
	{
		index=[dataobjects count];
		[dataobjects addObject:data];
	}

	NSMutableDictionary *dict=[NSMutableDictionary dictionaryWithObjectsAndKeys:
		[self XADPathWithString:name],XADFileNameKey,
		[NSNumber numberWithLongLong:length+[data length]],XADFileSizeKey,
		[NSNumber numberWithLongLong:length],@"SWFDataLengthKey",
		[NSNumber numberWithLongLong:offset],@"SWFDataOffsetKey",
		[self XADStringWithString:[parser isCompressed]?@"Zlib":@"None"],XADCompressionNameKey,
		[NSNumber numberWithInt:index],@"SWFDataIndex",
	nil];
	[self addEntryWithDictionary:dict];
}

-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum
{
	CSHandle *handle=nil;
	NSNumber *offsetnum=[dict objectForKey:@"SWFDataOffsetKey"];
	NSNumber *lengthnum=[dict objectForKey:@"SWFDataLengthKey"];
	if(offsetnum&&lengthnum)
	{
		handle=[[parser handle] nonCopiedSubHandleFrom:[offsetnum longLongValue]
		length:[lengthnum longLongValue]];
	}

	CSHandle *datahandle=nil;
	NSNumber *indexnum=[dict objectForKey:@"SWFDataIndex"];
	if(indexnum)
	{
		datahandle=[CSMemoryHandle memoryHandleForReadingData:
		[dataobjects objectAtIndex:[indexnum intValue]]];
	}

	if(handle&&datahandle)
	{
		return [CSMultiHandle multiHandleWithHandles:datahandle,handle,nil];
	}
	else if(datahandle)
	{
		return datahandle;
	}
	else
	{
		return handle;
	}
}

-(NSString *)formatName { return @"SWF"; }

@end
