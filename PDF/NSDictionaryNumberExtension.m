/*
 * NSDictionaryNumberExtension.m
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
#import "NSDictionaryNumberExtension.h"


@implementation NSDictionary (NumberExtension)

-(int)intValueForKey:(NSString *)key default:(int)def
{
	id obj=[self objectForKey:key];
	if(!obj||![obj isKindOfClass:[NSNumber class]]) return def;
	return [obj intValue];
}

-(unsigned int)unsignedIntValueForKey:(NSString *)key default:(unsigned int)def
{
	id obj=[self objectForKey:key];
	if(!obj||![obj isKindOfClass:[NSNumber class]]) return def;
	return [obj unsignedIntValue];
}

-(BOOL)boolValueForKey:(NSString *)key default:(BOOL)def
{
	id obj=[self objectForKey:key];
	if(!obj||![obj isKindOfClass:[NSNumber class]]) return def;
	return [obj boolValue];
}

-(float)floatValueForKey:(NSString *)key default:(float)def
{
	id obj=[self objectForKey:key];
	if(!obj||![obj isKindOfClass:[NSNumber class]]) return def;
	return [obj floatValue];
}

-(double)doubleValueForKey:(NSString *)key default:(double)def
{
	id obj=[self objectForKey:key];
	if(!obj||![obj isKindOfClass:[NSNumber class]]) return def;
	return [obj doubleValue];
}

-(NSString *)stringForKey:(NSString *)key default:(NSString *)def
{
	id obj=[self objectForKey:key];
	if(!obj||![obj isKindOfClass:[NSString class]]) return def;
	return obj;
}

-(NSArray *)arrayForKey:(NSString *)key
{
	id obj=[self objectForKey:key];
	if(!obj) return nil;
	else if([obj isKindOfClass:[NSArray class]]) return obj;
	else return [NSArray arrayWithObject:obj];
}

@end
