/*
 * StuffItXUtilities.h
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
#import "CSInputBuffer.h"

uint64_t ReadSitxP2(CSHandle *fh);
uint32_t ReadSitxUInt32(CSHandle *fh);
uint64_t ReadSitxUInt64(CSHandle *fh);
NSData *ReadSitxString(CSHandle *fh);
NSData *ReadSitxData(CSHandle *fh,int n);

uint64_t CSInputNextSitxP2(CSInputBuffer *fh);
