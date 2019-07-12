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
    XADMemoryHandle * handle = [CSMemoryHandle memoryHandleForWriting];
    XADZipParserCentralDirectoryRecord expectedCDR = [self _validCentralDirectoryRecord];
    expectedCDR.creatorversion = 0x01;
    expectedCDR.system = 0x02;
    expectedCDR.extractversion = 0x0304;
    expectedCDR.flags = 0x0506;
    expectedCDR.compressionmethod = 0x0708;
    expectedCDR.date = 0x090A0B0C;
    expectedCDR.crc = 0x0d0e0f10;
    expectedCDR.compsize = 0x11121314;
    expectedCDR.uncompsize = 0x15161718;
    expectedCDR.namelength = 0x1;
    expectedCDR.extralength = 0x1;
    expectedCDR.commentlength = 0x1;
    expectedCDR.startdisk = 0x2021;
    expectedCDR.infileattrib = 0x3031;
    expectedCDR.extfileattrib = 0x40414243;
    expectedCDR.locheaderoffset = 0x50515253;

    [self _writeCentralDirectoryRecord:expectedCDR withHandle:handle];

    // name
    [handle writeUInt8:0xff];
    // extra
    [handle writeUInt8:0xff];
    // comment
    [handle writeUInt8:0xff];


    [handle seekToFileOffset:0];

    XADZipParser * parser = [[XADZipParser alloc] init];
    [parser setHandle:handle];

    XADZipParserCentralDirectoryRecord cdr = [parser readCentralDirectoryRecord];

    XCTAssertEqual(cdr.system, expectedCDR.system);
    XCTAssertEqual(cdr.creatorversion, expectedCDR.creatorversion);
    XCTAssertEqual(cdr.extractversion, expectedCDR.extractversion);
    XCTAssertEqual(cdr.flags, expectedCDR.flags);
    XCTAssertEqual(cdr.compressionmethod, expectedCDR.compressionmethod);
    XCTAssertEqual(cdr.date, expectedCDR.date);
    XCTAssertEqual(cdr.crc, expectedCDR.crc);
    XCTAssertEqual(cdr.compsize, expectedCDR.compsize);
    XCTAssertEqual(cdr.uncompsize, expectedCDR.uncompsize);
    XCTAssertEqual(cdr.namelength, expectedCDR.namelength);
    XCTAssertEqual(cdr.extralength, expectedCDR.extralength);
    XCTAssertEqual(cdr.commentlength, expectedCDR.commentlength);
    XCTAssertEqual(cdr.startdisk, expectedCDR.startdisk);
    XCTAssertEqual(cdr.infileattrib, expectedCDR.infileattrib);
    XCTAssertEqual(cdr.extfileattrib, expectedCDR.extfileattrib);
    XCTAssertEqual(cdr.locheaderoffset, expectedCDR.locheaderoffset);

}

- (void)testReadingCentralDirectoryRecordWithExtraStartDisk
{
    XADMemoryHandle * handle = [CSMemoryHandle memoryHandleForWriting];
    XADZipParserCentralDirectoryRecord expectedCDR = [self _validCentralDirectoryRecord];

    expectedCDR.creatorversion = 0x01;
    expectedCDR.system = 0x02;
    expectedCDR.extractversion = 0x0304;
    expectedCDR.flags = 0x0506;
    expectedCDR.compressionmethod = 0x0708;
    expectedCDR.date = 0x090A0B0C;
    expectedCDR.crc = 0x0d0e0f10;
    expectedCDR.compsize = 0x11121314;
    expectedCDR.uncompsize = 0x15161718;
    expectedCDR.namelength = 0x0;
    expectedCDR.extralength = 0x0;
    expectedCDR.commentlength = 0x0;
    expectedCDR.startdisk = 0x2021;
    expectedCDR.infileattrib = 0x3031;
    expectedCDR.extfileattrib = 0x40414243;
    expectedCDR.locheaderoffset = 0x50515253;

    uint16_t extId = 1;
    uint32_t extraDisk = 0x01020304;
    uint16_t extSize = sizeof(extraDisk); // should be 4
    uint16_t extralength = sizeof(extId) + sizeof(extSize) + sizeof(extraDisk);

    // Start dis will go in ext field
    expectedCDR.startdisk = 0xffff;
    expectedCDR.extralength = extralength;

    [self _writeCentralDirectoryRecord:expectedCDR withHandle:handle];

    // writing extra field
    [handle writeInt16LE:extId];
    [handle writeInt16LE:extSize];
    [handle writeInt32LE:extraDisk];

    [handle seekToFileOffset:0];

    XADZipParser * parser = [[XADZipParser alloc] init];
    [parser setHandle:handle];

    XADZipParserCentralDirectoryRecord cdr = [parser readCentralDirectoryRecord];

    XCTAssertEqual(cdr.system, expectedCDR.system);
    XCTAssertEqual(cdr.creatorversion, expectedCDR.creatorversion);
    XCTAssertEqual(cdr.extractversion, expectedCDR.extractversion);
    XCTAssertEqual(cdr.flags, expectedCDR.flags);
    XCTAssertEqual(cdr.compressionmethod, expectedCDR.compressionmethod);
    XCTAssertEqual(cdr.date, expectedCDR.date);
    XCTAssertEqual(cdr.crc, expectedCDR.crc);
    XCTAssertEqual(cdr.compsize, expectedCDR.compsize);
    XCTAssertEqual(cdr.uncompsize, expectedCDR.uncompsize);
    XCTAssertEqual(cdr.namelength, expectedCDR.namelength);
    XCTAssertEqual(cdr.extralength, expectedCDR.extralength);
    XCTAssertEqual(cdr.commentlength, expectedCDR.commentlength);
    //XCTAssertEqual(cdr.startdisk, expectedCDR.startdisk);
    XCTAssertEqual(cdr.infileattrib, expectedCDR.infileattrib);
    XCTAssertEqual(cdr.extfileattrib, expectedCDR.extfileattrib);
    XCTAssertEqual(cdr.locheaderoffset, expectedCDR.locheaderoffset);

    // From extra field
    XCTAssertEqual(cdr.startdisk, 0x01020304);

}

- (void)testReadingCentralDirectoryRecordWithMultipleExtraFields
{
    XADMemoryHandle * handle = [CSMemoryHandle memoryHandleForWriting];
    XADZipParserCentralDirectoryRecord expectedCDR = [self _validCentralDirectoryRecord];

    expectedCDR.creatorversion = 0x01;
    expectedCDR.system = 0x02;
    expectedCDR.extractversion = 0x0304;
    expectedCDR.flags = 0x0506;
    expectedCDR.compressionmethod = 0x0708;
    expectedCDR.date = 0x090A0B0C;
    expectedCDR.crc = 0x0d0e0f10;
    expectedCDR.compsize = 0x11121314;
    expectedCDR.uncompsize = 0x15161718;
    expectedCDR.namelength = 0x0;
    expectedCDR.extralength = 0x0;
    expectedCDR.commentlength = 0x0;
    expectedCDR.startdisk = 0x2021;
    expectedCDR.infileattrib = 0x3031;
    expectedCDR.extfileattrib = 0x40414243;
    expectedCDR.locheaderoffset = 0x50515253;

    // Not so interested ext block
    uint16_t extId = 2;
    uint64_t someData = 0x1112131415161718;
    uint16_t extSize = sizeof(someData); // should be 8
    uint16_t extralength = sizeof(extId) + sizeof(extSize) + sizeof(someData);

    // block we interested in
    uint16_t extId2 = 1;
    uint64_t extraUncompSize = 0x0102030405060708;
    uint64_t extraCompSize = 0x1112131415161718;
    uint64_t localHeaderOffset = 0x2122232425262728;

    uint16_t extSize2 = sizeof(extraUncompSize) + sizeof(extraCompSize) + sizeof(localHeaderOffset);
    uint16_t extralength2 = sizeof(extId2) + sizeof(extSize2) + extSize2;


    // Comps size and uncomsize should go in extended block
    expectedCDR.compsize = 0xffffffff;
    expectedCDR.uncompsize = 0xffffffff;
    expectedCDR.locheaderoffset = 0xffffffff;
    expectedCDR.extralength = extralength + extralength2;

    [self _writeCentralDirectoryRecord:expectedCDR withHandle:handle];

    // writing Some non intersing extra field
    [handle writeInt16LE:extId];
    [handle writeInt16LE:extSize];
    [handle writeInt64LE:someData];

    // Second extra
    [handle writeInt16LE:extId2];
    [handle writeInt16LE:extSize2];
    [handle writeInt64LE:extraUncompSize];
    [handle writeInt64LE:extraCompSize];
    [handle writeInt64LE:localHeaderOffset];

    [handle seekToFileOffset:0];

    XADZipParser * parser = [[XADZipParser alloc] init];
    [parser setHandle:handle];

    XADZipParserCentralDirectoryRecord cdr = [parser readCentralDirectoryRecord];

    XCTAssertEqual(cdr.system, expectedCDR.system);
    XCTAssertEqual(cdr.creatorversion, expectedCDR.creatorversion);
    XCTAssertEqual(cdr.extractversion, expectedCDR.extractversion);
    XCTAssertEqual(cdr.flags, expectedCDR.flags);
    XCTAssertEqual(cdr.compressionmethod, expectedCDR.compressionmethod);
    XCTAssertEqual(cdr.date, expectedCDR.date);
    XCTAssertEqual(cdr.crc, expectedCDR.crc);
    XCTAssertEqual(cdr.namelength, expectedCDR.namelength);
    XCTAssertEqual(cdr.extralength, expectedCDR.extralength);
    XCTAssertEqual(cdr.commentlength, expectedCDR.commentlength);
    XCTAssertEqual(cdr.startdisk, expectedCDR.startdisk);
    XCTAssertEqual(cdr.infileattrib, expectedCDR.infileattrib);
    XCTAssertEqual(cdr.extfileattrib, expectedCDR.extfileattrib);

    // From extra field
    XCTAssertEqual(cdr.uncompsize, 0x0102030405060708);
    XCTAssertEqual(cdr.compsize, 0x1112131415161718);
    XCTAssertEqual(cdr.locheaderoffset, 0x2122232425262728);

}


#pragma mark - Private

- (XADZipParserCentralDirectoryRecord)_validCentralDirectoryRecord
{
    XADZipParserCentralDirectoryRecord result;
    result.centralid = 0x02014b50;
    result.system = 0x0;
    result.creatorversion = 0x0;
    result.extractversion = 0x0;
    result.flags = 0x0;
    result.compressionmethod = 0x0;
    result.date = 0x0;
    result.crc = 0x0;
    result.compsize = 0x0;
    result.uncompsize = 0x0;
    result.namelength = 0x0;
    result.extralength = 0x0;
    result.commentlength = 0x0;
    result.startdisk = 0x0;
    result.infileattrib = 0x0;
    result.extfileattrib = 0x0;
    result.locheaderoffset = 0x0;
    return result;
}

- (void)_writeCentralDirectoryRecord:(XADZipParserCentralDirectoryRecord)centralDirectoryRecord
                          withHandle:(XADMemoryHandle *)handle
{

    XADZipParserCentralDirectoryRecord cdr = centralDirectoryRecord;
    [handle writeInt32LE:cdr.centralid];

    [handle writeUInt8:cdr.creatorversion];
    [handle writeUInt8:cdr.system];

    [handle writeUInt16LE:cdr.extractversion];
    [handle writeUInt16LE:cdr.flags];
    [handle writeUInt16LE:cdr.compressionmethod];

    [handle writeUInt32LE:cdr.date];
    [handle writeUInt32LE:cdr.crc];

    [handle writeUInt32LE:(uint32_t)cdr.compsize];
    [handle writeUInt32LE:(uint32_t)cdr.uncompsize];

    [handle writeUInt16LE:cdr.namelength];
    [handle writeUInt16LE:cdr.extralength];
    [handle writeUInt16LE:cdr.commentlength];

    [handle writeUInt16LE:cdr.startdisk];
    [handle writeUInt16LE:cdr.infileattrib];

    [handle writeUInt32LE:cdr.extfileattrib];
    [handle writeUInt32LE:(uint32_t)cdr.locheaderoffset];
}

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
