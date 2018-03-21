/*
 * XADXARParser.h
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

#if MAC_OS_X_VERSION_MAX_ALLOWED>=1060
@interface XADXARParser:XADArchiveParser <NSXMLParserDelegate>
#else
@interface XADXARParser:XADArchiveParser
#endif
{
	off_t heapoffset;
	int state;

	NSDictionary *filedefinitions,*datadefinitions,*eadefinitions;

	NSMutableDictionary *currfile,*currea;
	NSMutableArray *files,*filestack,*curreas;
	NSMutableString *currstring;
}

+(int)requiredHeaderSize;
+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name;

-(void)parse;

-(void)finishFile:(NSMutableDictionary *)file parentPath:(XADPath *)parentpath;
-(XADString *)compressionNameForEncodingStyle:(NSString *)encodingstyle isXIP:(BOOL)isxip;

-(void)parser:(NSXMLParser *)parser didStartElement:(NSString *)name
namespaceURI:(NSString *)namespace qualifiedName:(NSString *)qname
attributes:(NSDictionary *)attributes;
-(void)parser:(NSXMLParser *)parser didEndElement:(NSString *)name
namespaceURI:(NSString *)namespace qualifiedName:(NSString *)qname;
-(void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string;

-(void)startSimpleElement:(NSString *)name attributes:(NSDictionary *)attributes
definitions:(NSDictionary *)definitions destinationDictionary:(NSMutableDictionary *)dest;
-(void)endSimpleElement:(NSString *)name definitions:(NSDictionary *)definitions
destinationDictionary:(NSMutableDictionary *)dest;
-(void)parseDefinition:(NSArray *)definition string:(NSString *)string
destinationDictionary:(NSMutableDictionary *)dest;

-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum;
-(CSHandle *)handleForEncodingStyle:(NSString *)encodingstyle offset:(NSNumber *)offset
length:(NSNumber *)length size:(NSNumber *)size checksum:(NSData *)checksum checksumStyle:(NSString *)checksumstyle;

-(NSString *)formatName;

@end
