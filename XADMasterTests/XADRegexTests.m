#import <XCTest/XCTest.h>
#import <XADMaster/XADRegex.h>

@interface XADRegexTests : XCTestCase
@end

@implementation XADRegexTests

- (void)testBeginMatchingDataOutOfBoundsRangeProducesNoMatch {
    XADRegex *regex = [XADRegex regexWithPattern:@"abc"];
    NSData *data = [@"abc" dataUsingEncoding:NSUTF8StringEncoding];

    [regex beginMatchingData:data range:NSMakeRange(1, 3)];

    XCTAssertFalse([regex matchNext]);
}

- (void)testBeginMatchingDataOverflowingRangeProducesNoMatch {
    XADRegex *regex = [XADRegex regexWithPattern:@"abc"];
    NSData *data = [@"abc" dataUsingEncoding:NSUTF8StringEncoding];
    NSRange range = NSMakeRange(NSUIntegerMax - 1, 4);

    [regex beginMatchingData:data range:range];

    XCTAssertFalse([regex matchNext]);
}

- (void)testMatchNextRespectsExplicitSubrange {
    XADRegex *regex = [XADRegex regexWithPattern:@"b+"];
    NSData *data = [@"abbbc" dataUsingEncoding:NSUTF8StringEncoding];

    [regex beginMatchingData:data range:NSMakeRange(1, 3)];

    XCTAssertTrue([regex matchNext]);
    XCTAssertEqualObjects([regex stringForMatch:0], @"bbb");
    XCTAssertFalse([regex matchNext]);
}

- (void)testBeginMatchingDataUsesStableSnapshotForMutableData {
    XADRegex *regex = [XADRegex regexWithPattern:@"abc"];
    NSMutableData *data = [NSMutableData dataWithData:[@"abc" dataUsingEncoding:NSUTF8StringEncoding]];
    const char *replacement = "xyz";

    [regex beginMatchingData:data];
    [data replaceBytesInRange:NSMakeRange(0, 3) withBytes:replacement];

    XCTAssertTrue([regex matchNext]);
    XCTAssertEqualObjects([regex stringForMatch:0], @"abc");
}

- (void)testNullMarkerIsDistinctFromAnEmptyMatch {
    // The null marker stands in for a capture group that took no part in the match, since
    // NSArray cannot hold nil. A group that did take part and matched an empty string has
    // to stay tellable apart from it, and identity is the only thing that separates them.
    NSArray *absent = [[XADRegex regexWithPattern:@"(a)?(b)"] capturedSubstringsOfString:@"b"];
    NSArray *empty = [[XADRegex regexWithPattern:@"(a*)(b)"] capturedSubstringsOfString:@"b"];

    XCTAssertEqual([absent objectAtIndex:1], [XADRegex null]);
    XCTAssertNotEqual([empty objectAtIndex:1], [XADRegex null]);
    XCTAssertEqualObjects([empty objectAtIndex:1], @"");
}

@end
