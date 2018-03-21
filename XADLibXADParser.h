/*
 * XADLibXADParser.h
 *
 * Copyright (c) 2017-present, MacPaw Inc. All rights reserved.
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
 * MA 02110-1301  USA
 */

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
	int numfilesadded,numdisksadded;

	NSMutableData *namedata;
}

+(int)requiredHeaderSize;
+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data
name:(NSString *)name propertiesToAdd:(NSMutableDictionary *)props;

-(id)init;
-(void)dealloc;

-(void)parse;
-(BOOL)newEntryCallback:(struct xadProgressInfo *)proginfo;
-(NSMutableDictionary *)dictionaryForFileInfo:(struct xadFileInfo *)info;
-(NSMutableDictionary *)dictionaryForDiskInfo:(struct xadDiskInfo *)info;

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
