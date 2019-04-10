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
#import "../CSHandle.h"
#import "../CSMemoryHandle.h"
#import "../XADRAR5Parser.h"

@interface XADRAR5Parser(Extensions)
+ (uint64_t)readRAR5VIntFrom:(CSHandle *)handle;
+ (BOOL)isPartOfMultiVolume:(CSHandle *)handle;
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

    
- (void)testMultipartIsMultipart {
    XADMemoryHandle *handle = [self rarHeaderOfType:RAR5HeaderTypeMain archiveFlags:RAR5ArchiveFlagsVolume];
    BOOL isMultivolume = [XADRAR5Parser isPartOfMultiVolume:handle];
    XCTAssertTrue(isMultivolume, @"Correct multivolume should be treated as multivolume");
}

- (void)testNonMainHeaderIsNotTreadedAsMultipart {
    XADMemoryHandle *handle = [self rarHeaderOfType:RAR5HeaderTypeEncryption archiveFlags:RAR5ArchiveFlagsNone];
    BOOL isMultivolume = [XADRAR5Parser isPartOfMultiVolume:handle];
    XCTAssertFalse(isMultivolume, @"Non main first header should not be treated as multipart");
}

- (void)testNonMultipartIsNotTreatedAsMultipart {
    XADMemoryHandle *handle = [self rarHeaderOfType:RAR5HeaderTypeMain archiveFlags:RAR5ArchiveFlagsNone];
    BOOL isMultivolume = [XADRAR5Parser isPartOfMultiVolume:handle];
    XCTAssertFalse(isMultivolume, @"Multipart should not be treated as multipart");
}

- (void)testMultipartIsDetectedInSFXArchives {
    XADMemoryHandle *handle = [self rarSFXHeaderOfType:RAR5HeaderTypeMain archiveFlags:RAR5ArchiveFlagsVolume];
    BOOL isMultivolume = [XADRAR5Parser isPartOfMultiVolume:handle];
    XCTAssertTrue(isMultivolume, @"Correct multivolume in SFX should be treated as multivolume");
}

- (void)testRAR5IsRecognizedForSFXArchives {
    XADMemoryHandle *handle = [self rarSFXHeaderOfType:RAR5HeaderTypeMain archiveFlags:RAR5ArchiveFlagsVolume];
    XCTAssertTrue([XADRAR5Parser recognizeFileWithHandle:handle firstBytes:[handle data] name:@""], @"Rar signature should be found in SFX archives");
}

- (void)testRAR5IsRecognizedForNonSFXArchives {
    XADMemoryHandle *handle = [self rarHeaderOfType:RAR5HeaderTypeMain archiveFlags:RAR5ArchiveFlagsVolume];
    XCTAssertTrue([XADRAR5Parser recognizeFileWithHandle:handle firstBytes:[handle data] name:@""], @"Rar signature should be found in SFX archives");
}

#pragma mark - Testing

- (XADMemoryHandle *)rarHeaderOfType:(RAR5HeaderType)type archiveFlags:(RAR5ArchiveFlags)flags
{
    uint8_t buffer[] = {
        // Header 8 bytes
        'R', 'a', 'r', '!', 0x1a, 0x07, 0x01, 0x00,
        
        // CRC 4 bytes
        0x00, 0x00, 0x00, 0x00,
        
        // HEADER size (vint)
        0x01,
        
        // Type
        (uint8_t)type,
        
        // Flags (vint)
        0x00,
        
        // Archive flags (vint)
        (uint8_t)flags
    };
    NSData * data = [NSData dataWithBytes:buffer length:sizeof(buffer)];
    XADMemoryHandle *handle = [CSMemoryHandle memoryHandleForReadingData:data];
    return handle;
}

- (XADMemoryHandle *)rarSFXHeaderOfType:(RAR5HeaderType)type archiveFlags:(RAR5ArchiveFlags)flags
{
    uint8_t buffer[] = {
        
        // random prefix (SFX)
        0x0A, 0xB0, 0xC0, 0xD0, 0x0E, 0x0E, 0xEE, 0xFF, 0x0E, 0x0E, 0xEE, 0xFF,

        // Header 8 bytes
        'R', 'a', 'r', '!', 0x1a, 0x07, 0x01, 0x00,
        
        // CRC 4 bytes
        0x00, 0x00, 0x00, 0x00,
        
        // HEADER size (vint)
        0x01,
        
        // Type
        (uint8_t)type,
        
        // Flags (vint)
        0x00,
        
        // Archive flags (vint)
        (uint8_t)flags
    };
    NSData * data = [NSData dataWithBytes:buffer length:sizeof(buffer)];
    XADMemoryHandle *handle = [CSMemoryHandle memoryHandleForReadingData:data];
    return handle;
}

@end

