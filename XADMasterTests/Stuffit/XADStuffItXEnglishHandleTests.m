/*
 * XADStuffItXEnglishHandleTests.m
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
#import "../../XADStuffItXEnglishHandle.h"

// StuffItX compresses English text by index: the stream carries a word number and the
// decoder substitutes the word itself. The dictionary behind that is roughly 100k
// English words, shipped as a compressed blob inside the binary and decoded once per
// process into a flat buffer of newline-separated words:
//
//     the\napple\nbanana\n...
//     ^    ^     ^
//     [0]  [1]   [2]
//
// dictionaryPointers indexes that buffer with one entry per word plus a closing
// boundary, which is what these tests cover.

// Mirrors the constants in XADStuffItXEnglishHandle.m.
#define NumberOfWords 100366
#define UncompressedSize 881863

// Mirrors the wordbuf ivar in XADStuffItXEnglishHandle.h.
#define WordBufferSize 33

// dictionaryPointers is internal to the implementation and not declared in the header.
@interface XADStuffItXEnglishHandle (Testing)
+ (const uint8_t **)dictionaryPointers;
@end

@interface XADStuffItXEnglishHandleTests : XCTestCase
@end

@implementation XADStuffItXEnglishHandleTests

- (void)testDictionaryTableIsFullyPopulated
{
	const uint8_t **pointers = [XADStuffItXEnglishHandle dictionaryPointers];
	XCTAssertTrue(pointers != NULL, @"Expected a built dictionary table");

	const uint8_t *start = pointers[0];
	XCTAssertTrue(start != NULL, @"Expected the first entry to point at the decoded data");

	// An entry left unfilled would hold zero or leftover malloc contents, breaking the
	// ordering — that is the corruption a partially built table produces.
	for (int i = 1; i <= NumberOfWords; i++)
	{
		if (pointers[i] <= pointers[i - 1])
		{
			XCTFail(@"Entry %d does not follow its predecessor", i);
			return;
		}
	}

	XCTAssertTrue(pointers[NumberOfWords] <= start + UncompressedSize,
		@"Last entry runs past the end of the decoded data");
}

// produceByteAtOffset: copies a word into the 33-byte wordbuf and then appends one more
// byte to it, without checking at runtime that either fits. The dictionary blob is a fixed
// part of the StuffItX format, so that holds today — this is what would catch it if the
// blob were ever replaced by one carrying longer words.
- (void)testLongestWordFitsInTheWordBuffer
{
	const uint8_t **pointers = [XADStuffItXEnglishHandle dictionaryPointers];

	ptrdiff_t longest = 0;
	for (int i = 0; i < NumberOfWords; i++)
	{
		ptrdiff_t wordlen = pointers[i + 1] - pointers[i] - 1;
		if (wordlen > longest) longest = wordlen;
	}

	XCTAssertLessThan(longest, (ptrdiff_t)WordBufferSize,
		@"Longest word no longer leaves room for the byte appended after it");
}

@end
