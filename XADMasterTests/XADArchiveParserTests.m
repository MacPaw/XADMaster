//
//  XADArchiveParserTests.m
//  XADMasterTests
//
//  Created by Paul Taykalo on 12/19/18.
//

#import <XCTest/XCTest.h>
#import "../XADArchiveParser.h"
@interface XADArchiveParserTests : XCTestCase
@property(nonatomic, strong) XADArchiveParser* parser;
@end

@implementation XADArchiveParserTests

- (void)setUp {
    [super setUp];
    self.parser = [[XADArchiveParser alloc] init];
}

- (void)testIncrementsIndexForEachEntry {

    NSMutableDictionary * firstEntry = [NSMutableDictionary dictionary];
    NSMutableDictionary * secondEntry = [NSMutableDictionary dictionary];
    [self.parser addEntryWithDictionary:firstEntry];
    [self.parser addEntryWithDictionary:secondEntry];

    XCTAssertEqualObjects(firstEntry[XADIndexKey], @0);
    XCTAssertEqualObjects(secondEntry[XADIndexKey], @1);
}

- (void)testExtractsPosixPermissions {
    NSMutableDictionary * entry = [NSMutableDictionary dictionary];
    entry[XADPosixPermissionsKey] = @(0x1000);
    [self.parser addEntryWithDictionary:entry];
    XCTAssertEqualObjects(entry[XADIsFIFOKey], @YES);

    entry = [NSMutableDictionary dictionary];
    entry[XADPosixPermissionsKey] = @(0x2000);
    [self.parser addEntryWithDictionary:entry];
    XCTAssertEqualObjects(entry[XADIsCharacterDeviceKey], @YES);

    entry = [NSMutableDictionary dictionary];
    entry[XADPosixPermissionsKey] = @(0x6000);
    [self.parser addEntryWithDictionary:entry];
    XCTAssertEqualObjects(entry[XADIsBlockDeviceKey], @YES);

    entry = [NSMutableDictionary dictionary];
    entry[XADPosixPermissionsKey] = @(0xa000);
    [self.parser addEntryWithDictionary:entry];
    XCTAssertEqualObjects(entry[XADIsLinkKey], @YES);
}

@end
