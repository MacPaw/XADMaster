/*
* XADRARParserTests.m
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
#import "../../XADRARParser.h"

@interface XADRARParser ()

-(XADPath *)parseNameData:(NSData *)data flags:(int)flags;

@end
@interface XADRARParserTests : XCTestCase

@end

@implementation XADRARParserTests

- (void)testParsingNameDataWithNoData {
    XADRARParser * sut = [XADRARParser new];
    XADPath * path = [sut parseNameData:nil flags:0];
    XCTAssertEqualObjects(path.string, @".");
}

- (void)testParsingNameDataWithSimplePath {
    XADRARParser * sut = [XADRARParser new];
    XADPath * path = [sut parseNameData:[@"hello/there" dataUsingEncoding:NSUTF8StringEncoding] flags:0];
    XCTAssertEqualObjects(path.string, @"hello/there");
}

- (void)testDataWithUnicodeWithNoZeroBytes {
    uint8_t buffer[] = {
        'a', 'b', 'c', '/', 'd'
    };
    NSData * data = [NSData dataWithBytes:buffer length:5];

    XADRARParser * sut = [XADRARParser new];
    XADPath * path = [sut parseNameData:data flags:0x0200];
    XCTAssertEqualObjects(path.string, @"abc/d");
}

- (void)testDataWithSomeUnicodeWithASCIISymbolsOnly {
    uint8_t buffer[] = {
        'a', 'b', 'c', 'd', 'e'
    };
    NSData * data = [NSData dataWithBytes:buffer length:5];

    XADRARParser * sut = [XADRARParser new];
    XADPath * path = [sut parseNameData:data flags:0x0200];
    XCTAssertEqualObjects(path.string, @"abcde");
}

- (void)testDataWithSimpleCase {
    uint8_t buffer[] = {
        'a', 'b', 0xc2, 0, 'd'
    };
    NSData * data = [NSData dataWithBytes:buffer length:5];

    XADRARParser * sut = [XADRARParser new];
    XADPath * path = [sut parseNameData:data flags:0x0200];
    XCTAssertEqualObjects(path.string, @"abﾂ");
}


- (void)testDataWithSomeUnicodeInIt {
    uint8_t buffer[] = {
        0, 0xc2, 0, 0xc2, 0xc3
    };
    NSData * data = [NSData dataWithBytes:buffer length:5];

    XADRARParser * sut = [XADRARParser new];
    XADPath * path = [sut parseNameData:data flags:0x0200];
    XCTAssertEqualObjects(path.string, @"ÂÃ");
}


@end
