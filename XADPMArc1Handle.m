#import "XADPMArc1Handle.h"

/*

Copyright (c) 2011, 2012, Simon Howard

Permission to use, copy, modify, and/or distribute this software
for any purpose with or without fee is hereby granted, provided
that the above copyright notice and this permission notice appear
in all copies.

THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL
WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE
AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR
CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM
LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT,
NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN
CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

*/

// self for -pm1- compressed files.
//
// This was difficult to put together. I can't find any versions of
// PMarc that will generate -pm1- encoded files (only -pm2-); however,
// the extraction tool, PMext, will extract them. I have therefore been
// able to reverse engineer the format and write a self. I am
// indebted to Alwin Henseler for publishing the Z80 assembly source to
// his UNPMA10 tool, which was apparently decompiled from the original
// PMarc and includes the -pm1- decoding code.

@implementation XADPMArc1Handle

#define MAX_BYTE_BLOCK_LEN 216

typedef struct {
	unsigned int offset;
	unsigned int bits;
} VariableLengthTable;

// Read a variable length code, given the header bits already read.
static int decode_variable_length(CSInputBuffer *input,
const VariableLengthTable *table,unsigned int header)
{
	int value=CSInputNextBitString(input,table[header].bits);
	return table[header].offset+value;
}

// Initialize the history buffer.

static void init_history_list(XADPMA1HistoryLinkedList *list)
{
	// History buffer is initialized to a linear chain to
	// start off with:
	for(int i=0;i<256;i++)
	{
		list->history[i].prev=(uint8_t)(i+1);
		list->history[i].next=(uint8_t)(i-1);
	}

	// The chain is cut into groups and initially arranged so
	// that the ASCII characters are closest to the start of
	// the chain. This is followed by ASCII control characters,
	// then various other groups.
	list->history_head=0x20;

	list->history[0x7f].prev=0x00;  // 0x20 ... 0x7f -> 0x00
	list->history[0x00].next=0x7f;

	list->history[0x1f].prev=0xa0;  // 0x00 ... 0x1f -> 0xa0
	list->history[0xa0].next=0x1f;

	list->history[0xdf].prev=0x80;  // 0xa0 ... 0xdf -> 0x80
	list->history[0x80].next=0xdf;

	list->history[0x9f].prev=0xe0;  // 0x80 ... 0x9f -> 0xe0
	list->history[0xe0].next=0x9f;

	list->history[0xff].prev=0x20;  // 0xe0 ... 0xff -> 0x20
	list->history[0x20].next=0xff;
}

// Look up an entry in the history list, returning the code found.
static uint8_t find_in_history_list(XADPMA1HistoryLinkedList *list,uint8_t count)
{
	// Start from the last outputted byte.
	uint8_t code=list->history_head;

	// Walk along the history chain until we reach the desired
	// node.  If we will have to walk more than half the chaisn,
	// go the other way around.
	if(count<128)
	{
		for(int i=0;i<count;i++) code=list->history[code].prev;
	}
	else
	{
		for(int i=0;i<256-count;i++) code=list->history[code].next;
	}

	return code;
}

// Update history list, by moving the specified byte to the head
// of the queue.
static void update_history_list(XADPMA1HistoryLinkedList *list,uint8_t b)
{
	// No update necessary?
	if(list->history_head==b) return;

	// Unhook the entry from its current position:
	XADPMA1HistoryNode *node=&list->history[b];
	list->history[node->next].prev=node->prev;
	list->history[node->prev].next=node->next;

	// Hook in between the old head and old_head->next:
	XADPMA1HistoryNode *old_head=&list->history[list->history_head];
	node->prev=list->history_head;
	node->next=old_head->next;

	list->history[old_head->next].prev=b;
	old_head->next=b;

	// 'b' is now the head of the queue:
	list->history_head=b;
}

// Table used to decode distance into history buffer to copy data.
static const VariableLengthTable copy_ranges[]=
{
	{    0,  6 },  //    0 +  (1 << 6) =    64
	{   64,  8 },  //   64 +  (1 << 8) =   320
	{    0,  6 },  //    0 +  (1 << 6) =    64
	{   64,  9 },  //   64 +  (1 << 9) =   576
	{  576, 11 },  //  576 + (1 << 11) =  2624
	{ 2624, 13 },  // 2624 + (1 << 13) = 10816

	// The above table entries are used after a certain number of
	// bytes have been decoded.
	// Early in the stream, some of the copy ranges are more limited
	// in their range, so that fewer bits are needed. The above
	// table entries are redirected to these entries instead.

	// Table entry #3 (64):
	{   64,  8 },   // < 320 bytes

	// Table entry #4 (576):
	{  576,  8 },   // < 832 bytes
	{  576,  9 },   // < 1088 bytes
	{  576, 10 },   // < 1600 bytes

	// Table entry #5 (2624):
	{ 2624,  8 },   // < 2880 bytes
	{ 2624,  9 },   // < 3136 bytes
	{ 2624, 10 },   // < 3648 bytes
	{ 2624, 11 },   // < 4672 bytes
	{ 2624, 12 },   // < 6720 bytes
};

// Table used to decode byte values.

static const VariableLengthTable byte_ranges[]=
{
	{   0, 4 },  //   0 + (1 << 4) = 16
	{  16, 4 },  //  16 + (1 << 4) = 32
	{  32, 5 },  //  32 + (1 << 5) = 64
	{  64, 6 },  //  64 + (1 << 6) = 128
	{ 128, 6 },  // 128 + (1 << 6) = 191
	{ 192, 6 },  // 192 + (1 << 6) = 255
};

// This table is a list of trees to decode indices into byte_ranges.
// Each line is actually a mini binary tree, starting with the first
// byte as the root node. Each nybble of the byte is one of the two
// branches: either a leaf value (a-f) or an offset to the child node.
// Expanded representation is shown in comments below.

static const uint8_t byte_decode_trees[][5]=
{
	{ 0x12, 0x2d, 0xef, 0x1c, 0xab },    // ((((a b) c) d) (e f))
	{ 0x12, 0x23, 0xde, 0xab, 0xcf },    // (((a b) (c f)) (d e))
	{ 0x12, 0x2c, 0xd2, 0xab, 0xef },    // (((a b) c) (d (e f)))
	{ 0x12, 0xa2, 0xd2, 0xbc, 0xef },    // ((a (b c)) (d (e f)))

	{ 0x12, 0xa2, 0xc2, 0xbd, 0xef },    // ((a (b d)) (c (e f)))
	{ 0x12, 0xa2, 0xcd, 0xb1, 0xef },    // ((a (b (e f))) (c d))
	{ 0x12, 0xab, 0x12, 0xcd, 0xef },    // ((a b) ((c d) (e f)))
	{ 0x12, 0xab, 0x1d, 0xc1, 0xef },    // ((a b) ((c (e f)) d))

	{ 0x12, 0xab, 0xc1, 0xd1, 0xef },    // ((a b) (c (d (e f))))
	{ 0xa1, 0x12, 0x2c, 0xde, 0xbf },    // (a (((b f) c) (d e)))
	{ 0xa1, 0x1d, 0x1c, 0xb1, 0xef },    // (a (((b (e f)) c) d))
	{ 0xa1, 0x12, 0x2d, 0xef, 0xbc },    // (a (((b c) d) (e f)))

	{ 0xa1, 0x12, 0xb2, 0xde, 0xcf },    // (a ((b (c f)) (d e)))
	{ 0xa1, 0x12, 0xbc, 0xd1, 0xef },    // (a ((b c) (d (e f))))
	{ 0xa1, 0x1c, 0xb1, 0xd1, 0xef },    // (a ((b (d (e f))) c))
	{ 0xa1, 0xb1, 0x12, 0xcd, 0xef },    // (a (b ((c d) (e f))))

	{ 0xa1, 0xb1, 0xc1, 0xd1, 0xef },    // (a (b (c (d (e f)))))
	{ 0x12, 0x1c, 0xde, 0xab },          // (((d e) c) (d e)) <- BROKEN!
	{ 0x12, 0xa2, 0xcd, 0xbe },          // ((a (b e)) (c d))
	{ 0x12, 0xab, 0xc1, 0xde },          // ((a b) (c (d e)))

	{ 0xa1, 0x1d, 0x1c, 0xbe },          // (a (((b e) c) d))
	{ 0xa1, 0x12, 0xbc, 0xde },          // (a ((b c) (d e)))
	{ 0xa1, 0x1c, 0xb1, 0xde },          // (a ((b (d e)) c))
	{ 0xa1, 0xb1, 0xc1, 0xde },          // (a (b (c (d e))))

	{ 0x1d, 0x1c, 0xab },                // (((a b) c) d)
	{ 0x1c, 0xa1, 0xbd },                // ((a (b d)) c)
	{ 0x12, 0xab, 0xcd },                // ((a b) (c d))
	{ 0xa1, 0x1c, 0xbd },                // (a ((b d) c))

	{ 0xa1, 0xb1, 0xcd },                // (a (b (c d)))
	{ 0xa1, 0xbc },                      // (a (b c))
	{ 0xab },                            // (a b)
	{ 0x00 },                            // -- special entry: 0, no tree
};

// Decode a count of the number of bytes to copy in a copy command.
static int read_copy_byte_count(XADPMArc1Handle *self)
{
	// This is a form of static huffman encoding that uses less bits
	// to encode short copy amounts (again).

	// Value in the range 3..5?
	// Length values start at 3: if it was 2, a different copy
	// range would have been used and this function would not
	// have been called.
	int x=CSInputNextBitString(self->input,2);
	if(x<3) return x+3;

	x=CSInputNextBitString(self->input,3);
	if(x<5) // Value in range 6..10?
	{
		return x+6;
	}
	else if(x==5) // Value in range 11..14?
	{
		x=CSInputNextBitString(self->input,2);
		return x+11;
	}
	else if(x==6) // Value in range 15..22?
	{
		x=CSInputNextBitString(self->input,3);
		return x+15;
	}
	// else x == 7...

	x=CSInputNextBitString(self->input,6);

	if(x<62)
	{
		return x+23;
	}
	else if(x==62) // Value in range 85..116?
	{
		x=CSInputNextBitString(self->input,5);
		return x+85;
	}
	else // x = 63 - Value in range 117..244
	{
		x=CSInputNextBitString(self->input,7);
		return x+117;
	}
}

// Read a single bit from the input stream, but only once the specified
// point is reached in the output stream. Before that point is reached,
// return the value of 'def' instead.
static int NextBitAfterThreshold(CSInputBuffer *input,unsigned int pos,unsigned int threshold,int def)
{
	if(pos>=threshold) return CSInputNextBit(input);
	else return def;
}

// Read the range index for the copy type used when performing a copy command.
static int read_copy_type_range(XADPMArc1Handle *self,unsigned int pos)
{
	// This is another static huffman tree, but the path grows as
	// more data is decoded. The progression is as follows:
	//  1. Initially, only '0' and '2' can be returned.
	//  2. After 64 bytes, '1' and '3' can be returned as well.
	//  3. After 576 bytes, '4' can be returned.
	//  4. After 2624 bytes, '5' can be returned.

	int x=CSInputNextBit(self->input);

	if(x==0)
	{
		x=NextBitAfterThreshold(self->input,pos,576,0);

		if(x!=0) return 4;
		else return NextBitAfterThreshold(self->input,pos,64,0); // Return either 0 or 1.
	}
	else
	{
		x=NextBitAfterThreshold(self->input,pos,64,1);

		if(x==0) return 3;

		x=NextBitAfterThreshold(self->input,pos,2624,1);

		if(x!=0) return 2;
		else return 5;
	}
}

// Read the index into the byte decode table, using the byte_decode_tree
// set at the start of the stream.
static int read_byte_decode_index(XADPMArc1Handle *self)
{
	const uint8_t *ptr=self->byte_decode_tree;
	if(ptr[0]==0) return 0;

	// Walk down the tree, reading a bit at each node to determine
	// which path to take.
	for(;;)
	{
		int bit=CSInputNextBit(self->input);

		unsigned int child;
		if(bit==0) child=(*ptr>>4)&0x0f;
		else child=*ptr&0x0f;

		// Reached a leaf node?
		if(child>=10) return child-10;

		ptr+=child;
	}
}

// Read a single byte value from the input stream.
static int read_byte(XADPMArc1Handle *self)
{
	// Read the index into the byte_ranges table to use.
	int index=read_byte_decode_index(self);

	// Decode value using byte_ranges table. This is actually
	// a distance to walk along the history linked list - it
	// is static huffman encoding, so that recently used byte
	// values use fewer bits.
	int count=decode_variable_length(self->input,byte_ranges,index);

	// Walk through the history linked list to get the actual
	// value.
	return find_in_history_list(&self->history_list,count);
}

// Read the length of a block of bytes.
static int read_byte_block_count(CSInputBuffer *input)
{
	// This is a form of static huffman coding, where smaller
	// lengths are encoded using shorter bit sequences.

	// Value in the range 1..3?
	int x=CSInputNextBitString(input,2);
	if(x<3) return x+1;

	// Value in the range 4..10?
	x=CSInputNextBitString(input,3);
	if(x<7) return x+4;

	// Value in the range 11..25?
	x=CSInputNextBitString(input,4);
	if(x<14)
	{
		return x+11;
	}
	else if(x==14)
	{
		// Value in the range 25-88:
		return CSInputNextBitString(input,6)+25;
	}
	else // x==15
	{
		// Value in the range 89-216:
		return CSInputNextBitString(input,7)+89;
	}
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length
{
	return [super initWithHandle:handle length:length windowSize:2048];
}

-(void)resetLZSSHandle
{
	bytesleft=0;
	nextismatch=false;

	init_history_list(&history_list);

	// Read the 5-bit header from the start of the input stream. This
	// specifies the table entry to use for byte decodes.
	int index=CSInputNextBitString(input,5);
	byte_decode_tree=byte_decode_trees[index];
}

-(int)nextLiteralOrOffset:(int *)offset andLength:(int *)length atPosition:(off_t)pos
{
	if(bytesleft)
	{
		bytesleft--;
		return read_byte(self);
	}
	else
	{
		if(nextismatch || CSInputNextBit(input)==0)
		{
			nextismatch=false;

			int range_index=read_copy_type_range(self,pos);

			// The first two entries in the copy_ranges table are used as
			// a shorthand to copy two bytes. Otherwise, decode the number
			// of bytes to copy.
			int count;
			if(range_index<2) count=2;
			else count=read_copy_byte_count(self);

			// The 'range_index' variable is an index into the copy_ranges
			// array. As a special-case hack, early in the output stream
			// some history ranges are inaccessible, so fewer bits can be
			// used. Redirect range_index to special entries to do this.
			if(range_index==3)
			{
				if(pos<320) range_index=6;
			}
			else if(range_index==4)
			{
				if(pos<832) range_index=7;
				else if(pos<1088) range_index=8;
				else if(pos<1600) range_index=9;
			}
			else if(range_index==5)
			{
				if(pos<2880) range_index=10;
				else if(pos<3136) range_index=11;
				else if(pos<3648) range_index=12;
				else if(pos<4672) range_index=13;
				else if(pos<6720) range_index=14;
			}

			// Calculate the number of bytes back into the history buffer
			// to read.
			int history_distance=decode_variable_length(self->input,copy_ranges,range_index);

			*offset=history_distance+1;
			*length=count;

			return XADLZSSMatch;
		}
		else
		{
			bytesleft=read_byte_block_count(self->input);
			if(bytesleft<216) nextismatch=true;

			return [self nextLiteralOrOffset:offset andLength:length atPosition:pos];
		}
	}
}

-(uint8_t)produceByteAtOffset:(off_t)pos
{
	uint8_t byte=[super produceByteAtOffset:pos];
//NSLog(@"%02x %c",byte,byte);
	update_history_list(&history_list,byte);

	return byte;
}

@end

