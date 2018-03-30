/*
 * XADPlatformOSXTests.m
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
#import <XADMaster/XADPlatform.h>

@interface XADPlatformOSXTests : XCTestCase
@property (nonatomic, copy) NSString *fileWithQuarantineData;

@end

@interface XADPlatformOSXTests (Helpers)
- (NSString *)createTemporaryFile;
@end

@implementation XADPlatformOSXTests

- (void)setUp {
    [super setUp];
    self.fileWithQuarantineData = [self createTemporaryFile];
}


-(void)testReadingFromNilFileWillNotFail {
    XCTAssertNoThrow([XADPlatform readCloneableMetadataFromPath:nil], @"We should not fail on reading from nil");
}

- (void)testQuarantineDataExists {
    id readData = [XADPlatform readCloneableMetadataFromPath:self.fileWithQuarantineData];
    XCTAssertNotNil(readData, @"There should be quarantine data on created file");

}
- (void)testCloneableMetadataReadsSameThatWrites {

    id expectedData = [XADPlatform readCloneableMetadataFromPath:self.fileWithQuarantineData];
    NSString *temporaryFile = [self createTemporaryFile];
    [XADPlatform writeCloneableMetadata:expectedData toPath:temporaryFile];
    id actualData = [XADPlatform readCloneableMetadataFromPath:temporaryFile];

    XCTAssertNotNil(actualData, @"Metadata should be read successfully");
    XCTAssertEqualObjects(actualData, expectedData, @"Metadata should be equal to one that was stored in it");
}


- (void)dealloc {
    self.fileWithQuarantineData = nil;
    [super dealloc];
}

@end

@implementation XADPlatformOSXTests (Helpers)

- (NSString *)createTemporaryFile {
    NSString *tempDir = NSTemporaryDirectory();
    NSUUID *uuid = [[NSUUID new] autorelease];
    NSString *name = [uuid UUIDString];
    NSString *filename = [[tempDir stringByAppendingPathComponent:name] stringByAppendingPathExtension:@"tmp"];
    [name writeToFile:filename atomically:NO encoding:NSUTF8StringEncoding error:nil];
    [[NSURL fileURLWithPath:filename] setResourceValue:@{} forKey:@"NSURLQuarantinePropertiesKey" error:NULL];

    return filename;

}
@end
