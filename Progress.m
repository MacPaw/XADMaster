/*
 * Progress.m
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
#import "Progress.h"


@implementation CSHandle (Progress)

-(double)estimatedProgress
{
	off_t size=[self fileSize];
	if(size==CSHandleMaxLength) return 0;
	if(size==1) return 1;
	return (double)[self offsetInFile]/(double)size;
}

@end

@implementation CSStreamHandle (progress)

-(double)estimatedProgress
{
	if(streamlength==CSHandleMaxLength)
	{
		if(input) return [input->parent estimatedProgress]; // TODO: better estimation
		else return 0;
	}
	else return (double)streampos/(double)streamlength;
}

@end

@implementation CSZlibHandle (Progress)

-(double)estimatedProgress { return [parent estimatedProgress]; } // TODO: better estimation using buffer?

@end

@implementation CSBzip2Handle (progress)

-(double)estimatedProgress { return [parent estimatedProgress]; } // TODO: better estimation using buffer?

@end

// TODO: more handles like LZMA?
