/*
 * XADPMArc1Handle.h
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
#import "XADLZSSHandle.h"

typedef struct {
	uint8_t prev;
	uint8_t next;
} XADPMA1HistoryNode;

// History linked list. In the decode stream, codes representing
// characters are not the character itself, but the number of
// nodes to count back in time in the linked list. Every time
// a character is output, it is moved to the front of the linked
// list. The entry point index into the list is the last output
// character, given by history_head;

typedef struct {
	XADPMA1HistoryNode history[256];
	uint8_t history_head;
} XADPMA1HistoryLinkedList;

@interface XADPMArc1Handle:XADLZSSHandle
{
	int bytesleft;
	bool nextismatch;

	// Pointer to the entry in byte_decode_table used to decode
	// byte value indices.
	const uint8_t *byte_decode_tree;

	// History linked list, for adaptively encoding byte values.
	XADPMA1HistoryLinkedList history_list;
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length;
-(int)nextLiteralOrOffset:(int *)offset andLength:(int *)length atPosition:(off_t)pos;

@end
