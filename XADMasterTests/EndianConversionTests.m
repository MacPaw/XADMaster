//
//  EndianConversionTests.m
//  XADMasterTests
//

#import <XCTest/XCTest.h>
#import "../libxad/include/xadmaster.h"
#import "../libxad/include/ConvertE.c"

@interface EndianConversionTests : XCTestCase

@end

@implementation EndianConversionTests

- (void)testEndGetM32ParsesDMSMagic {
    const unsigned char bytes[] = { 'D', 'M', 'S', '!' };

    XCTAssertEqual(EndGetM32(bytes), (xadUINT32)0x444D5321u);
}

- (void)testEndGetM32HandlesHighBitSetMostSignificantByteWithoutSignedOverflow {
    // This is the UBSan reproducer for the legacy implementation:
    // the old macro evaluated `201 << 24` as a signed int shift.
    const unsigned char bytes[] = { 201, 0x44, 0x53, 0x21 };

    XCTAssertEqual(EndGetM32(bytes), (xadUINT32)0xC9445321u);
}

@end
