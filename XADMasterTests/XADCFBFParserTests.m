/*
 * XADCFBFParserTests.m
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
#import "../XADCFBFParser.h"

@interface XADCFBFParser (TestExtensions)
- (int)sanitizedNameLength:(int)numnamebytes fromBuffer:(const uint8_t *)bytes;
@end

@interface XADCFBFParserTests : XCTestCase
@property (nonatomic, strong) XADCFBFParser *parser;
@end

@implementation XADCFBFParserTests

- (void)setUp
{
    [super setUp];
    self.parser = [[XADCFBFParser alloc] init];
}

#pragma mark - Valid length (≤ 64) — must pass through unchanged

- (void)testValidLengthIsPassedThrough
{
    // "AB\0" in UTF-16LE — 6 bytes including the null terminator
    uint8_t name[64] = {0};
    name[0] = 'A'; name[1] = 0x00;
    name[2] = 'B'; name[3] = 0x00;
    name[4] = 0x00; name[5] = 0x00;

    XCTAssertEqual([self.parser sanitizedNameLength:6 fromBuffer:name], 6);
}

- (void)testZeroLengthIsPassedThrough
{
    uint8_t name[64] = {0};
    XCTAssertEqual([self.parser sanitizedNameLength:0 fromBuffer:name], 0);
}

- (void)testMaxValidLengthIsPassedThrough
{
    // 64 is the exact buffer size — still a legal declared value
    uint8_t name[64] = {0};
    XCTAssertEqual([self.parser sanitizedNameLength:64 fromBuffer:name], 64);
}

#pragma mark - Oversized length — fall back to scanning for UTF-16LE null

- (void)testOversizedLengthFindsNullTerminatorMidBuffer
{
    // "Root\0" in UTF-16LE: null terminator at bytes 8–9 → recovered length = 10
    uint8_t name[64] = {0};
    name[0] = 'R'; name[1] = 0x00;
    name[2] = 'o'; name[3] = 0x00;
    name[4] = 'o'; name[5] = 0x00;
    name[6] = 't'; name[7] = 0x00;
    name[8] = 0x00; name[9] = 0x00; // null terminator

    // 66 is the exact malformed value from PR #187 (one over the 64-byte limit)
    XCTAssertEqual([self.parser sanitizedNameLength:66 fromBuffer:name], 10);
}

- (void)testOversizedLengthFindsNullAtStart
{
    // Buffer starts with a UTF-16LE null word → recovered length = 2
    uint8_t name[64] = {0};
    XCTAssertEqual([self.parser sanitizedNameLength:0xFF fromBuffer:name], 2);
}

- (void)testOversizedLengthFindsNullAtLastValidPosition
{
    // Null terminator at bytes 62–63 (last UTF-16LE slot) → recovered length = 64
    uint8_t name[64];
    memset(name, 0xAB, sizeof(name));
    name[62] = 0x00;
    name[63] = 0x00;

    XCTAssertEqual([self.parser sanitizedNameLength:66 fromBuffer:name], 64);
}

#pragma mark - Oversized length with no null terminator — must raise

- (void)testOversizedLengthWithNoNullTerminatorRaises
{
    // No UTF-16LE null word anywhere in the 64-byte buffer
    uint8_t name[64];
    memset(name, 0xAB, sizeof(name));

    XCTAssertThrows([self.parser sanitizedNameLength:66 fromBuffer:name]);
}

- (void)testMaxOversizedLengthWithNoNullTerminatorRaises
{
    uint8_t name[64];
    memset(name, 0xFF, sizeof(name));

    XCTAssertThrows([self.parser sanitizedNameLength:0xFFFF fromBuffer:name]);
}

@end
