/*
 * CSMultiHandle.m
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
#import "CSMultiHandle.h"

@implementation CSMultiHandle

+(CSHandle *)handleWithHandleArray:(NSArray *)handlearray
{
	if(!handlearray) return nil;
	NSInteger count=[handlearray count];
	if(count==0) return nil;
	else if(count==1) return [handlearray objectAtIndex:0];
	else return [[[self alloc] initWithHandles:handlearray] autorelease];
}

+(CSHandle *)handleWithHandles:(CSHandle *)firsthandle,...
{
	if(!firsthandle) return nil;

	NSMutableArray *array=[NSMutableArray arrayWithObject:firsthandle];
	CSHandle *handle;
	va_list va;

	va_start(va,firsthandle);
	while((handle=va_arg(va,CSHandle *))) [array addObject:handle];
	va_end(va);

	return [self handleWithHandleArray:array];
}

-(id)initWithHandles:(NSArray *)handlearray
{
	if(self=[super init])
	{
		handles=[handlearray copy];
	}
	return self;
}

-(id)initAsCopyOf:(CSMultiHandle *)other
{
	if(self=[super initAsCopyOf:other])
	{
		NSMutableArray *handlearray=[NSMutableArray arrayWithCapacity:[other->handles count]];
		NSEnumerator *enumerator=[other->handles objectEnumerator];
		CSHandle *handle;
		while((handle=[enumerator nextObject])) [handlearray addObject:[[handle copy] autorelease]];

		handles=[[NSArray arrayWithArray:handlearray] retain];
	}
	return self;
}

-(void)dealloc
{
	[handles release];
	[super dealloc];
}

-(NSArray *)handles { return handles; }

-(NSInteger)numberOfSegments { return [handles count]; }

-(off_t)segmentSizeAtIndex:(NSInteger)index
{
	return [[handles objectAtIndex:index] fileSize];
}

-(CSHandle *)handleAtIndex:(NSInteger)index
{
	return [handles objectAtIndex:index];
}

@end
