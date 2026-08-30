/*
 * XADStuffItXIronHandleTests.m
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

#import <XCTest/XCTest.h>
#import "../../CSMemoryHandle.h"
#import "../../XADException.h"
#import "../../XADStuffItXIronHandle.h"

@interface XADStuffItXIronHandleTests : XCTestCase
@end

@implementation XADStuffItXIronHandleTests

- (void)testOversizedBlockRaisesIllegalData
{
	// Bit layout (LSB-first within each byte), encoding 2^31 via CSInputNextSitxP2:
	// bit  0     = 0   stream bit — not end of stream
	// bits 1-2   = 1,0 prefix: one leading 1-bit → n=2
	// bit  3     = 1   value loop: value |= 1, n→1
	// bits 4-33  = 0   30 zeros — bit counter advances to 2^31
	// bit  34    = 1   value loop: value |= 2^31, n→0
	//                  CSInputNextSitxP2 returns 2^31 = INT_MAX+1
	uint8_t bytes[] = {0x0A, 0x00, 0x00, 0x00, 0x04};

	NSException *caught =
		[self caughtExceptionProducingBlockWithBytes:bytes
											  length:sizeof(bytes)];

	XCTAssertNotNil(caught, @"Expected XADException to be thrown");
	XCTAssertEqualObjects(caught.name, XADExceptionName);
	XCTAssertEqual([caught.userInfo[@"XADError"] intValue], XADIllegalDataError);
}

// Demonstrates the crash path where blocksize*6 overflows unsigned int to a tiny
// allocation. blocksize=715827883 is below INT_MAX so the rawblocksize > INT_MAX
// guard does not fire. Without the fix, unsigned int arithmetic wraps
// 715827883*6 → 2, so malloc(2) succeeds and sorted lands ~680 MB beyond the
// 2-byte block, causing EXC_BAD_ACCESS — a hardware signal that @try/@catch
// cannot catch, so the test runner crashes before reaching any assertion.
// With the fix, size_t arithmetic gives the correct ~4 GB allocation size.
// malloc either returns NULL (→ XADOutOfMemoryException) or succeeds and
// decoding hits EOF on the tiny input (→ CSEndOfFileException). Either way
// the process survives, which is the only assertion we can reliably make here.
- (void)testBlockSizeWithMultiplicationOverflow
{
	// blocksize=715827883: 715827883*6 mod 2^32 = 2 → malloc(2) without fix
	// Bit layout: stream=0, prefix 14×1 + 0 (n=15), value loop = 0x2AAAAAAC bits,
	//             compressed=0, firstindex=0
	uint8_t bytes[] = {
		0xFE, 0x7F,                          // stream bit + prefix (14 ones → 0)
		0xAC, 0xAA, 0xAA, 0x2A, 0x01,       // blocksize value loop + compressed + firstindex
		0x00,                                // skip byte in decodeBlockWithLength
		0x00, 0x00, 0x00, 0x00,              // InitializeRangeCoder
		0x00, 0x00, 0x00, 0x00,              // decode data (crash before any is consumed)
		0x00, 0x00, 0x00, 0x00,
	};

	NSException *caught =
		[self caughtExceptionProducingBlockWithBytes:bytes
											  length:sizeof(bytes)];

	XCTAssertNotNil(caught, @"Expected an exception, not a hard crash");
}

#pragma mark - Helpers

- (NSException *)caughtExceptionProducingBlockWithBytes:(uint8_t *)bytes length:(size_t)length
{
	CSMemoryHandle *handle =
		[CSMemoryHandle memoryHandleForReadingBuffer:bytes
											  length:(unsigned int)length];
	XADStuffItXIronHandle *ironHandle =
		[[XADStuffItXIronHandle alloc] initWithHandle:handle
											   length:CSHandleMaxLength];
	NSException *caught = nil;
	@try {
		[ironHandle produceBlockAtOffset:0];
	} @catch (NSException *e) {
		caught = e;
	}
	[ironHandle release];
	return caught;
}

@end
