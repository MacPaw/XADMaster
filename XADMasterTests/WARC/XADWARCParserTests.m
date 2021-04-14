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

@interface XADWARCParserTestDelegate: NSObject
@property(nonatomic, strong) NSDictionary * entry;
@end

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

- (void)testShouldCorrectlyFindsFileEntryIn10version {
    NSURL * _Nullable fixtureURL = [[NSBundle bundleForClass:[XADWARCParserTests class]] URLForResource:@"warc-example-1.0" withExtension:nil subdirectory:@"WARCFixtures"];
    NSData * data = [NSData dataWithContentsOfURL:fixtureURL];
    XADMemoryHandle *handle = [CSMemoryHandle memoryHandleForReadingData:data];
    
    XCTAssertTrue([XADWARCParser recognizeFileWithHandle:handle firstBytes:data name:@""]);
    
    XADWARCParserTestDelegate * delegate = [XADWARCParserTestDelegate new];
    XADWARCParser * parser = (XADWARCParser *)[XADWARCParser archiveParserForHandle:handle name:@""];
    parser.delegate = delegate;
    [parser parse];
    
    XCTAssertNotNil(delegate.entry);
    XCTAssertEqualObjects(delegate.entry[@"XADFileSize"], @2396);
}

- (void)testShouldCorrectlyFindsEntryIn11Version {
    NSURL * _Nullable fixtureURL = [[NSBundle bundleForClass:[XADWARCParserTests class]] URLForResource:@"warc-example-1.1" withExtension:nil subdirectory:@"WARCFixtures"];
    NSData * data = [NSData dataWithContentsOfURL:fixtureURL];
    XADMemoryHandle *handle = [CSMemoryHandle memoryHandleForReadingData:data];
    
    XCTAssertTrue([XADWARCParser recognizeFileWithHandle:handle firstBytes:data name:@""]);
    
    XADWARCParserTestDelegate * delegate = [XADWARCParserTestDelegate new];
    XADWARCParser * parser = (XADWARCParser *)[XADWARCParser archiveParserForHandle:handle name:@""];
    parser.delegate = delegate;
    [parser parse];
    
    XCTAssertNotNil(delegate.entry);
    XCTAssertEqualObjects(delegate.entry[@"XADFileSize"], @2396);
}

@end



@implementation XADWARCParserTestDelegate

- (void)archiveParser:(XADArchiveParser *)parser foundEntryWithDictionary:(NSDictionary *)dict {
    self.entry = dict;
}

@end
