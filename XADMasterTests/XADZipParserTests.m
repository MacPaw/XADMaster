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

- (void)testExtendedTimestampExtraFieldParsingModificationTime
{
    XADZipParserTestsSUT sut = [self _handleWithExtendedTimeStampModificationTime:YES value:5
                                                                       accessTime:NO value:0
                                                                     creationTime:NO value:0];
    XADZipParser *parser = sut.parser;

    NSDictionary * result = [parser parseZipExtraWithLength:9 nameData:nil uncompressedSizePointer:nil compressedSizePointer:nil];

    NSDate * date = result[XADLastModificationDateKey];
    XCTAssertNotNil(date);

    NSDate * expectedDate = [NSDate dateWithTimeIntervalSince1970:5];
    XCTAssertEqualObjects(expectedDate, date);
}

- (void)testExtendedTimestampExtraFieldParsingAccessTime
{
    XADZipParserTestsSUT sut = [self _handleWithExtendedTimeStampModificationTime:NO value:0
                                                                       accessTime:YES value:7
                                                                     creationTime:NO value:0];
    XADZipParser *parser = sut.parser;

    NSDictionary * result = [parser parseZipExtraWithLength:9 nameData:nil uncompressedSizePointer:nil compressedSizePointer:nil];

    NSDate * date = result[XADLastAccessDateKey];
    XCTAssertNotNil(date);

    NSDate * expectedDate = [NSDate dateWithTimeIntervalSince1970:7];
    XCTAssertEqualObjects(expectedDate, date);
}

- (void)testExtendedTimestampExtraFieldParsingCreationTime
{
    XADZipParserTestsSUT sut = [self _handleWithExtendedTimeStampModificationTime:NO value:0
                                                                       accessTime:NO value:7
                                                                     creationTime:YES value:11];
    XADZipParser *parser = sut.parser;

    NSDictionary * result = [parser parseZipExtraWithLength:9 nameData:nil uncompressedSizePointer:nil compressedSizePointer:nil];

    NSDate * date = result[XADCreationDateKey];
    XCTAssertNotNil(date);

    NSDate * expectedDate = [NSDate dateWithTimeIntervalSince1970:11];
    XCTAssertEqualObjects(expectedDate, date);
}

- (void)testExtendedTimestampExtraFieldParsingAllPossibleTimes
{
    XADZipParserTestsSUT sut = [self _handleWithExtendedTimeStampModificationTime:YES value:5
                                                                       accessTime:YES value:6
                                                                     creationTime:YES value:7];
    XADZipParser *parser = sut.parser;

    NSDictionary * result = [parser parseZipExtraWithLength:9 nameData:nil uncompressedSizePointer:nil compressedSizePointer:nil];

    NSDate * modificationDate = result[XADLastModificationDateKey];
    XCTAssertEqualObjects([NSDate dateWithTimeIntervalSince1970:5], modificationDate);

    NSDate * lastAccessDate = result[XADLastAccessDateKey];
    XCTAssertEqualObjects([NSDate dateWithTimeIntervalSince1970:6], lastAccessDate);

    NSDate * creationDate = result[XADCreationDateKey];
    XCTAssertEqualObjects([NSDate dateWithTimeIntervalSince1970:7], creationDate);

}

- (void)testReadingCentralDirectoryRecord
{
    off_t fileSize = 200;
    uint8_t * initial = malloc(fileSize);
    uint8_t * buffer = initial;

    memset(buffer, 0, fileSize);

    // central id
    *(buffer++) = 0x50;
    *(buffer++) = 0x4b;
    *(buffer++) = 0x01;
    *(buffer++) = 0x02;

    //    version made by                 2 bytes
    *(buffer++) = 0x02;
    *(buffer++) = 0x01;

    //    version needed to extract       2 bytes
    *(buffer++) = 0x04;
    *(buffer++) = 0x03;

    //    general purpose bit flag        2 bytes
    *(buffer++) = 0x06;
    *(buffer++) = 0x05;

    //    compression method              2 bytes
    *(buffer++) = 0x08;
    *(buffer++) = 0x07;

    //    last mod file time              2 bytes
    *(buffer++) = 0x0C;
    *(buffer++) = 0x0B;

    //    last mod file date              2 bytes
    *(buffer++) = 0x0A;
    *(buffer++) = 0x09;

    //    crc-32                          4 bytes
    *(buffer++) = 0x10;
    *(buffer++) = 0x0f;
    *(buffer++) = 0x0e;
    *(buffer++) = 0x0d;

    //    compressed size                 4 bytes
    *(buffer++) = 0x14;
    *(buffer++) = 0x13;
    *(buffer++) = 0x12;
    *(buffer++) = 0x11;

    //    uncompressed size               4 bytes
    *(buffer++) = 0x18;
    *(buffer++) = 0x17;
    *(buffer++) = 0x16;
    *(buffer++) = 0x15;

    //    file name length                2 bytes
    *(buffer++) = 0x01;
    *(buffer++) = 0x00;

    //    extra field length              2 bytes
    *(buffer++) = 0x01;
    *(buffer++) = 0x00;

    //    file comment length             2 bytes
    *(buffer++) = 0x01;
    *(buffer++) = 0x00;

    //    disk number start               2 bytes
    *(buffer++) = 0x21;
    *(buffer++) = 0x20;

    //    internal file attributes        2 bytes
    *(buffer++) = 0x31;
    *(buffer++) = 0x30;

    //    external file attributes        4 bytes
    *(buffer++) = 0x43;
    *(buffer++) = 0x42;
    *(buffer++) = 0x41;
    *(buffer++) = 0x40;

    //    relative offset of local header 4 bytes
    *(buffer++) = 0x53;
    *(buffer++) = 0x52;
    *(buffer++) = 0x51;
    *(buffer++) = 0x50;

    XADMemoryHandle *handle = [CSMemoryHandle memoryHandleForReadingBuffer:initial length:fileSize];
    XADZipParser * parser = [[XADZipParser alloc] init];
    [parser setHandle:handle];

    XADZipParserCentralDirectoryRecord cdr = [parser readCentralDirectoryRecord];

    XCTAssertEqual(cdr.system, 0x01);
    XCTAssertEqual(cdr.creatorversion, 0x02);
    XCTAssertEqual(cdr.extractversion, 0x0304);
    XCTAssertEqual(cdr.flags, 0x0506);
    XCTAssertEqual(cdr.compressionmethod, 0x0708);
    XCTAssertEqual(cdr.date, 0x090A0B0C);
    XCTAssertEqual(cdr.crc, 0x0D0E0F10);
    XCTAssertEqual(cdr.compsize, 0x11121314);
    XCTAssertEqual(cdr.uncompsize, 0x15161718);
    XCTAssertEqual(cdr.namelength, 0x01);
    XCTAssertEqual(cdr.extralength, 0x01);
    XCTAssertEqual(cdr.commentlength, 0x01);
    XCTAssertEqual(cdr.startdisk, 0x2021);
    XCTAssertEqual(cdr.infileattrib, 0x3031);
    XCTAssertEqual(cdr.extfileattrib, 0x40414243);
    XCTAssertEqual(cdr.locheaderoffset, 0x50515253);

}

#pragma mark - Private

- (XADZipParserTestsSUT)_handleWithExtendedTimeStampModificationTime:(BOOL)modificationTime value:(int32_t)modificationValue
                                                          accessTime:(BOOL)accessTime value:(int32_t)accessValue
                                                        creationTime:(BOOL)creationTime value:(int32_t)creationValue
{

    XADMemoryHandle * handle = [CSMemoryHandle memoryHandleForWriting];

    // ExtId ( Extended time stamp)
    [handle writeInt16LE:0x5455];

    // field size
    int16_t fieldSize = 1 + (4 * (modificationTime ? 1 : 0 + accessTime ? 1 : 0 + creationTime ? 1: 0));
    [handle writeInt16LE:fieldSize];

    //      The lower three bits of Flags in both headers indicate which time-
    //          stamps are present in the LOCAL extra field:
    //
    //                bit 0           if set, modification time is present
    //                bit 1           if set, access time is present
    //                bit 2           if set, creation time is present
    int8_t bits = 0;
    if (modificationTime){
        bits |= 1 << 0;
    }
    if (accessTime){
        bits |= 1 << 1;
    }
    if (creationTime){
        bits |= 1 << 2;
    }

    [handle writeInt8:bits];

    // number of seconds since 1 January 1970 00:00:00.
    if (modificationTime) {
        [handle writeInt32LE:modificationValue];
    }
    if (accessTime) {
        [handle writeInt32LE:accessValue];
    }
    if (creationTime) {
        [handle writeInt32LE:creationValue];
    }

    [handle seekToFileOffset:0];

    XADZipParser * parser = [[XADZipParser alloc] init];
    [parser setHandle:handle];

    return (XADZipParserTestsSUT){
        NULL,
        handle,
        parser
    };
}

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
    if (sut.buffer != NULL) {
        free(sut.buffer);
    }
}

@end
