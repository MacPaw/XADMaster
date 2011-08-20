#import "XADUnarchiver.h"
#import "CSFileHandle.h"

@implementation XADUnarchiver (AppleDouble)

-(XADError)_extractResourceForkEntryWithDictionary:(NSDictionary *)dict asAppleDoubleFile:(NSString *)destpath
{
	// AppleDouble format referenced from:
	// http://www.opensource.apple.com/source/Libc/Libc-391.2.3/darwin/copyfile.c

	CSHandle *fh;
	@try { fh=[CSFileHandle fileHandleForWritingAtPath:destpath]; }
	@catch(id e) { return XADOpenFileError; }

	// AppleDouble header template.
	uint8_t header[0x32]=
	{
		/*  0 */ 0x00,0x05,0x16,0x07, 0x00,0x02,0x00,0x00,
		/*  8 */ 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
		/* 24 */ 0x00,0x02,
		/* 26 */ 0x00,0x00,0x00,0x09, 0x00,0x00,0x00,0x32, 0x00,0x00,0x00,0x00,
		/* 38 */ 0x00,0x00,0x00,0x02, 0x00,0x00,0x00,0x00, 0x00,0x00,0x00,0x00,
		/* 50 */
	};

	NSDictionary *extattrs=[parser extendedAttributesForDictionary:dict];

	// Calculate FinderInfo and extended attributes size field.
	int numattributes=0,attributeentrysize=0,attributedatasize=0;

	// Sort keys and iterate over them.
	NSArray *keys=[[extattrs allKeys] sortedArrayUsingSelector:@selector(compare:)];
	NSEnumerator *enumerator=[keys objectEnumerator];
	NSString *key;
	while((key=[enumerator nextObject]))
	{
		// Ignore FinderInfo.
		if([key isEqual:@"com.apple.FinderInfo"]) continue;

 		NSData *data=[extattrs objectForKey:key];
		int namelen=[key lengthOfBytesUsingEncoding:NSUTF8StringEncoding]+1;
		if(namelen>128) continue; // Skip entries with too long names.

		numattributes++;
		attributeentrysize+=(11+namelen+3)&~3; // Aligned to 4 bytes.
		attributedatasize+=[data length];
	}

	// Set FinderInfo size field and resource fork offset field.
	if(numattributes)
	{
		CSSetUInt32BE(&header[34],32+38+attributeentrysize+attributedatasize);
		CSSetUInt32BE(&header[42],50+32+38+attributeentrysize+attributedatasize);
	}
	else
	{
		CSSetUInt32BE(&header[34],32);
		CSSetUInt32BE(&header[42],50+32);
	}

	// Set resource fork size field.
	off_t ressize=0;
	NSNumber *sizenum=[dict objectForKey:XADFileSizeKey];
	if(sizenum) ressize=[sizenum longLongValue];
	CSSetUInt32BE(&header[46],ressize);

	// Write AppleDouble header.
	[fh writeBytes:sizeof(header) fromBuffer:header];

	// Write FinderInfo structure.
	NSData *finderinfo=[extattrs objectForKey:@"com.apple.FinderInfo"];
	if(finderinfo)
	{
		if([finderinfo length]<32) return XADUnknownError;
		[fh writeBytes:32 fromBuffer:[finderinfo bytes]];
	}
	else
	{
		uint8_t emptyfinderinfo[32]={ 0x00 };
		[fh writeBytes:32 fromBuffer:emptyfinderinfo];
	}

	// Write extended attributes if needed.
	if(numattributes)
	{
		// Attributes section header template.
		uint8_t attributesheader[38]=
		{
			/*  0 */ 0x00,0x00,
			/*  2 */  'A', 'T', 'T', 'R', 0x00,0x00,0x00,0x00,
			/* 10 */ 0x00,0x00,0x00,0x00, 0x00,0x00,0x00,0x00,
			/* 18 */ 0x00,0x00,0x00,0x00, 0x00,0x00,0x00,0x00,
			/* 26 */ 0x00,0x00,0x00,0x00, 0x00,0x00,0x00,0x00,
			/* 34 */ 0x00,0x00, 0x00,0x00,
			/* 38 */
		};

		int datastart=50+32+38+attributeentrysize;

		// Set header fields.
		CSSetUInt32BE(&attributesheader[10],datastart+attributedatasize); // total_size
		CSSetUInt32BE(&attributesheader[14],datastart); // data_start
		CSSetUInt32BE(&attributesheader[18],attributedatasize); // data_length
		CSSetUInt16BE(&attributesheader[36],numattributes); // num_attrs

		// Write attributes section header.
		[fh writeBytes:sizeof(attributesheader) fromBuffer:attributesheader];

		// Write attribute entries.
		int currdataoffset=datastart;
		NSEnumerator *enumerator=[keys objectEnumerator];
		NSString *key;
		while((key=[enumerator nextObject]))
		{
			// Ignore FinderInfo.
			if([key isEqual:@"com.apple.FinderInfo"]) continue;

			NSData *data=[extattrs objectForKey:key];
			int namelen=[key lengthOfBytesUsingEncoding:NSUTF8StringEncoding]+1;
			if(namelen>128) continue; // Skip entries with too long names.

			// Attribute entry header template.
			uint8_t entryheader[11]=
			{
				/*  0 */ 0x00,0x00,0x00,0x00, 0x00,0x00,0x00,0x00,
				/*  8 */ 0x00,0x00, namelen,
				/* 11 */ 
			};

			// Set entry header fields.
			CSSetUInt32BE(&entryheader[0],currdataoffset); // offset
			CSSetUInt32BE(&entryheader[4],[data length]); // length

			// Write entry header.
			[fh writeBytes:sizeof(entryheader) fromBuffer:entryheader];

			// Write name.
			char namebytes[namelen];
			[key getCString:namebytes maxLength:namelen encoding:NSUTF8StringEncoding];
			[fh writeBytes:namelen fromBuffer:namebytes];

			// Calculate and write padding.
			int padbytes=(-(namelen+11))&3;
			uint8_t zerobytes[4]={ 0x00 };
			[fh writeBytes:padbytes fromBuffer:zerobytes];

			// Update data pointer.
			currdataoffset+=[data length];
		}

		// Write attribute data.
		enumerator=[keys objectEnumerator];
		while((key=[enumerator nextObject]))
		{
			// Ignore FinderInfo.
			if([key isEqual:@"com.apple.FinderInfo"]) continue;

			NSData *data=[extattrs objectForKey:key];
			int namelen=[key lengthOfBytesUsingEncoding:NSUTF8StringEncoding]+1;
			if(namelen>128) continue; // Skip entries with too long names.

			[fh writeData:data];
		}
	}

	// Write resource fork.
	XADError error=XADNoError;
	if(ressize) error=[self runExtractorWithDictionary:dict outputHandle:fh];

	[fh close];

	return error;
}

@end

