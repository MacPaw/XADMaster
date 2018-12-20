//
//  XADZipParserTests.m
//  XADMasterTests
//
//  Created by Paul Taykalo on 12/19/18.
//

#import <XCTest/XCTest.h>
#import "../CSMemoryHandle.h"
#import "../XADZipParser.h"

typedef struct XADZipParserTestsSUT {
    uint8_t * buffer;
    XADMemoryHandle * handle;
    XADZipParser * parser;
} XADZipParserTestsSUT;

@interface XADZipParserTests : XCTestCase

@end

@implementation XADZipParserTests

- (void)testCentralDirectoryLocationNotFound
{
    XADZipParserTestsSUT sut = [self _handleWithCDOffset:-1 inFileSize:0x1000];
    XADZipParser *parser = sut.parser;

    off_t centralRecordOffset = -1;
    off_t zip64Offset = -1;
    [parser findCentralDirectoryRecordOffset:&centralRecordOffset zip64Offset:&zip64Offset];
    XCTAssertEqual(centralRecordOffset, -1);
    XCTAssertEqual(zip64Offset, -1);

    [self _free:sut];

}

- (void)testCentralDirectoryLocationInSmallFile
{
    XADZipParserTestsSUT sut = [self _handleWithCDOffset:35 inFileSize:50];
    XADZipParser *parser = sut.parser;

    off_t centralRecordOffset = -1;
    off_t zip64Offset = -1;
    [parser findCentralDirectoryRecordOffset:&centralRecordOffset zip64Offset:&zip64Offset];
    XCTAssertEqual(centralRecordOffset, 35);
    XCTAssertEqual(zip64Offset, 15);

    [self _free:sut];
}

- (void)testCentralDirectoryLocationInRecordOffsetBetweenChunks
{
    for (int offset = -20; offset< 20; offset++) {
        XADZipParserTestsSUT sut = [self _handleWithCDOffset:0x10000 + offset inFileSize:0x20000];
        XADZipParser *parser = sut.parser;

        off_t centralRecordOffset = -1;
        off_t zip64Offset = -1;
        [parser findCentralDirectoryRecordOffset:&centralRecordOffset zip64Offset:&zip64Offset];
        XCTAssertEqual(centralRecordOffset, 0x10000 + offset);
        XCTAssertEqual(zip64Offset, 0x10000 + offset - 20);

        [self _free:sut];
    }
}

- (void)testCentralDirectoryLocationInLargeFile
{
    XADZipParserTestsSUT sut = [self _handleWithCDOffset:105 inFileSize:0x10000];
    XADZipParser *parser = sut.parser;

    off_t centralRecordOffset = -1;
    off_t zip64Offset = -1;
    [parser findCentralDirectoryRecordOffset:&centralRecordOffset zip64Offset:&zip64Offset];
    XCTAssertEqual(centralRecordOffset, 105);
    XCTAssertEqual(zip64Offset, 85);

    [self _free:sut];
}

- (void)testCentralDirectoryLocationInVeryLargeFile
{
    XADZipParserTestsSUT sut = [self _handleWithCDOffset:35 inFileSize:0x1000000];
    XADZipParser *parser = sut.parser;

    off_t centralRecordOffset = -1;
    off_t zip64Offset = -1;
    [parser findCentralDirectoryRecordOffset:&centralRecordOffset zip64Offset:&zip64Offset];
    XCTAssertEqual(centralRecordOffset, 35);
    XCTAssertEqual(zip64Offset, 15);

    [self _free:sut];
}

#pragma mark - Private

- (XADZipParserTestsSUT)_handleWithCDOffset:(off_t)cdoffset inFileSize:(off_t)fileSize {
    uint8_t * buffer = malloc(fileSize);
    memset(buffer, 0, fileSize);
    if (cdoffset != -1)
    {
        // zip 64
        buffer[cdoffset - 20] = 'P';
        buffer[cdoffset - 19] = 'K';
        buffer[cdoffset - 18] = 0x06;
        buffer[cdoffset - 17] = 0x07;

        // CDL
        buffer[cdoffset    ] = 'P';
        buffer[cdoffset + 1] = 'K';
        buffer[cdoffset + 2] = 0x05;
        buffer[cdoffset + 3] = 0x06;
    }

    XADMemoryHandle *handle = [CSMemoryHandle memoryHandleForReadingBuffer:buffer length:fileSize];
    XADZipParser * parser = [[XADZipParser alloc] init];
    [parser setHandle:handle];

    return (XADZipParserTestsSUT){
        buffer,
        handle,
        parser
    };
}

- (void)_free:(XADZipParserTestsSUT)sut {
    free(sut.buffer);
}

@end
