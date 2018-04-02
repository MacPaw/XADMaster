/*
 * XADRAR5ParserTests.m
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
//#import <XADMaster/CSHandle.h>
#import "../CSHandle.h"
#import "../CSMemoryHandle.h"

@interface XADRAR5Parser : NSObject
+ (uint64_t)readRAR5VIntFrom:(CSHandle *)handle;
@end


@interface XADRAR5ParserTests : XCTestCase

@end

@implementation XADRAR5ParserTests

- (void)testReadingVariableInt1 {
    uint8_t buffer[] = {
        0x01
    };
    XADMemoryHandle *handle = [CSMemoryHandle memoryHandleForReadingBuffer:buffer length:sizeof(buffer)];
    uint64_t vint = [XADRAR5Parser readRAR5VIntFrom:handle];
    XCTAssertEqual(vint, (uint64_t) 1, @"Variable int should handle 7 bit sequences");
}

- (void)testReadingVariableInt7bits {
    uint8_t buffer[] = {
        0x80 | 0x00,
        0x01
    };
    XADMemoryHandle *handle = [CSMemoryHandle memoryHandleForReadingBuffer:buffer length:sizeof(buffer)];
    uint64_t vint = [XADRAR5Parser readRAR5VIntFrom:handle];
    XCTAssertEqual(vint, (uint64_t) 1 << 7, @"Variable int should handle 14 bit sequences");
}

- (void)testReadingVariableInt21bits {
    uint8_t buffer[] = {
        0x80 | 0x00,
        0x80 | 0x00,
        0x80 | 0x00,
        0x01
    };
    XADMemoryHandle *handle = [CSMemoryHandle memoryHandleForReadingBuffer:buffer length:sizeof(buffer)];
    uint64_t vint = [XADRAR5Parser readRAR5VIntFrom:handle];
    XCTAssertEqual(vint, (uint64_t) 1 << 21, @"Variable int should handle 21 bit sequences");
}

- (void)testReadingVariableInt35bits {
    uint8_t buffer[] = {
        0x80 | 0x00,
        0x80 | 0x00,
        0x80 | 0x00,
        0x80 | 0x00,
        0x80 | 0x00,
        0x01
    };
    XADMemoryHandle *handle = [CSMemoryHandle memoryHandleForReadingBuffer:buffer length:sizeof(buffer)];
    uint64_t vint = [XADRAR5Parser readRAR5VIntFrom:handle];
    XCTAssertEqual(vint, (uint64_t) 1 << 35, @"Variable int should handle 21 bit sequences");
}

- (void)testReadingVariableInt49bits {
    uint8_t buffer[] = {
        0x80 | 0x00,
        0x80 | 0x00,
        0x80 | 0x00,
        0x80 | 0x00,
        0x80 | 0x00,
        0x80 | 0x00,
        0x80 | 0x00,
        0x01
    };
    XADMemoryHandle *handle = [CSMemoryHandle memoryHandleForReadingBuffer:buffer length:sizeof(buffer)];
    uint64_t vint = [XADRAR5Parser readRAR5VIntFrom:handle];
    XCTAssertEqual(vint, (uint64_t) 1 << 49, @"Variable int should handle 21 bit sequences");
}


@end

