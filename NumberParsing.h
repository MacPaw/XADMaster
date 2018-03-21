/*
 * NumberParsing.h
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
#import "CSHandle.h"

int64_t ParseNumberWithBase(const char *num,int length,int base);
int64_t ParseDecimalNumber(const char *num,int length);
int64_t ParseHexadecimalNumber(const char *num,int length);
int64_t ParseOctalNumber(const char *num,int length);

@interface CSHandle (NumberParsing)

-(int64_t)readDecimalNumberWithDigits:(int)numdigits;
-(int64_t)readHexadecimalNumberWithDigits:(int)numdigits;
-(int64_t)readOctalNumberWithDigits:(int)numdigits;

@end
