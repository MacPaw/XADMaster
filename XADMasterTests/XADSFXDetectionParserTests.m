//
//  XADSFXDetectionParserTests.m
//  XADMasterTests
//
//  Created by Paul Taykalo on 4/10/19.
//

#import <XCTest/XCTest.h>

#import "../XADRARParser.h"
#import "../XADZipSFXParsers.h"
#import "../XADArchiveParser.h"
#import "../CSHandle.h"
#import "../CSMemoryHandle.h"

@interface XADSFXDetectionParserTests : XCTestCase {
    int fileSize;
    uint8_t * buffer;
}

@end

@implementation XADSFXDetectionParserTests

- (void)setUp {
    [super setUp];
    fileSize = 0x10000;
    buffer = malloc(fileSize);
    memset(buffer, 0, fileSize);
}

- (void)tearDown {
    free(buffer);
    [super tearDown];
}

- (void)testRARSFXArchiveDetected {

    NSInteger rarSignatureOffset = 1000;
    [self setupRarSignatureWithOffset:rarSignatureOffset];
    NSMutableDictionary * propertiestToAdd = [NSMutableDictionary dictionary];

    XADMemoryHandle *handle = [CSMemoryHandle memoryHandleForReadingBuffer:buffer length:fileSize];
    NSData *header=[handle readDataOfLengthAtMost:fileSize];

    Class clz = [XADArchiveParser archiveParserClassForHandle:handle firstBytes:header resourceFork:nil name:@"" propertiesToAdd:propertiestToAdd];
    XCTAssertEqualObjects(clz, [XADEmbeddedRARParser class], @"Embedded rar parser should be detected");
}

- (void)testZipSFXArchiveDetected {

    NSInteger zipSignatureOffset = 2000;
    [self setupZipSFXSignatureWithOffset:zipSignatureOffset];
    NSMutableDictionary * propertiestToAdd = [NSMutableDictionary dictionary];
    XADMemoryHandle *handle = [CSMemoryHandle memoryHandleForReadingBuffer:buffer length:fileSize];
    NSData *header=[handle readDataOfLengthAtMost:fileSize];

    Class clz = [XADArchiveParser archiveParserClassForHandle:handle firstBytes:header resourceFork:nil name:@"" propertiesToAdd:propertiestToAdd];
    XCTAssertEqualObjects(clz, [XADZipSFXParser class], @"Embedded rar parser should be detected");
}

- (void)testZipRarSignatureDetectedAsZip {
    [self setupZipSFXSignatureWithOffset: 5000];
    [self setupRarSignatureWithOffset   :10000];

    NSMutableDictionary * propertiestToAdd = [NSMutableDictionary dictionary];
    XADMemoryHandle *handle = [CSMemoryHandle memoryHandleForReadingBuffer:buffer length:fileSize];
    NSData *header=[handle readDataOfLengthAtMost:fileSize];

    Class clz = [XADArchiveParser archiveParserClassForHandle:handle firstBytes:header resourceFork:nil name:@"" propertiesToAdd:propertiestToAdd];
    XCTAssertEqualObjects(clz, [XADZipSFXParser class], @"Embedded rar parser should be detected");
}

- (void)testRarZipSignatureDetectedAsRar {
    [self setupRarSignatureWithOffset   : 5000];
    [self setupZipSFXSignatureWithOffset:10000];

    NSMutableDictionary * propertiestToAdd = [NSMutableDictionary dictionary];
    XADMemoryHandle *handle = [CSMemoryHandle memoryHandleForReadingBuffer:buffer length:fileSize];
    NSData *header=[handle readDataOfLengthAtMost:fileSize];

    Class clz = [XADArchiveParser archiveParserClassForHandle:handle firstBytes:header resourceFork:nil name:@"" propertiesToAdd:propertiestToAdd];
    XCTAssertEqualObjects(clz, [XADEmbeddedRARParser class], @"Embedded rar parser should be detected");
}


- (void)setupRarSignatureWithOffset:(NSInteger)offset {
    buffer[offset + 0] = 'R';
    buffer[offset + 1] = 'a';
    buffer[offset + 2] = 'r';
    buffer[offset + 3] = '!';
    buffer[offset + 4] = 0x1a;
    buffer[offset + 5] = 0x07;
    buffer[offset + 6] = 0x00;

}

- (void)setupZipSFXSignatureWithOffset:(NSInteger)offset {

    // MZ :) Long time no see
    buffer[0] = 0x4d;
    buffer[1] = 0x5a;


    buffer[offset + 0] = 'P';
    buffer[offset + 1] = 'K';
    buffer[offset + 2] = 3;
    buffer[offset + 3] = 4;
    buffer[offset + 4] = 11;  // > 10 && M 40
    // ...
    buffer[offset + 9] = 0x00;
}



@end
