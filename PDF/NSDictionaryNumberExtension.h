/*
 * NSDictionaryNumberExtension.h
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

@interface NSDictionary (NumberExtension)

-(int)intValueForKey:(NSString *)key default:(int)def;
-(unsigned int)unsignedIntValueForKey:(NSString *)key default:(unsigned int)def;
-(BOOL)boolValueForKey:(NSString *)key default:(BOOL)def;
-(float)floatValueForKey:(NSString *)key default:(float)def;
-(double)doubleValueForKey:(NSString *)key default:(double)def;

-(NSString *)stringForKey:(NSString *)key default:(NSString *)def;
-(NSArray *)arrayForKey:(NSString *)key;

@end
