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
