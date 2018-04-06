/*
 * CSJSONPrinter.h
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
#import <Foundation/Foundation.h>


@interface CSJSONPrinter:NSObject
{
	int indentlevel;
	NSString *indentstring;
	BOOL asciimode;

	BOOL needseparator;
	NSArray *excludedKeys;
}

-(id)init;
-(void)dealloc;

-(void)setIndentString:(NSString *)string;
-(void)setASCIIMode:(BOOL)ascii;
-(void)setExcludedKeys:(NSArray*)keysToExclude;

-(void)printObject:(id)object;

-(void)printNull;
-(void)printNumber:(NSNumber *)number;
-(void)printString:(NSString *)string;
-(void)printData:(NSData *)data;
-(void)printValue:(NSValue *)value;
-(void)printArray:(NSArray *)array;
-(void)printDictionary:(NSDictionary *)dictionary;

-(void)startPrintingArray;
-(void)startPrintingArrayObject;
-(void)printArrayObject:(id)object;
-(void)endPrintingArray;
-(void)printArrayObjects:(NSArray *)array;

-(void)startPrintingDictionary;
-(void)startPrintingDictionaryObjectForKey:(id)key;
-(void)printDictionaryObject:(id)object forKey:(id)key;
-(void)endPrintingDictionary;
-(void)printDictionaryKeysAndObjects:(NSDictionary *)dictionary;

-(void)startNewLine;
-(void)printSeparatorIfNeeded;

-(NSString *)stringByEscapingString:(NSString *)string;
-(NSString *)stringByEncodingBytes:(const uint8_t *)bytes length:(int)length;

@end
