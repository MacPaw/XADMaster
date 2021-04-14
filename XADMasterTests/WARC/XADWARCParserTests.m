//
//  XADWARCParserTests.m
//  XADMasterTests
//
//  Created by Taykalo on 14.04.2021.
//

#import <XCTest/XCTest.h>
#import "../../CSHandle.h"
#import "../../CSMemoryHandle.h"
#import "../../XADWARCParser.h"

@interface XADWARCParserTests : XCTestCase

@end

@implementation XADWARCParserTests

- (void)testShouldRecognize10Archives {
    NSData * data =
    [@"WARC/1.0\r\n"
     dataUsingEncoding:NSUTF8StringEncoding];
    XADMemoryHandle *handle = [CSMemoryHandle memoryHandleForReadingData:data];

    XCTAssertTrue([XADWARCParser recognizeFileWithHandle:handle firstBytes:data name:@""]);
}

- (void)testShouldRecognize11Archives {
    NSData * data =
    [@"WARC/1.1\r\n"
     dataUsingEncoding:NSUTF8StringEncoding];
    XADMemoryHandle *handle = [CSMemoryHandle memoryHandleForReadingData:data];

    XCTAssertTrue([XADWARCParser recognizeFileWithHandle:handle firstBytes:data name:@""]);
}

@end
