//
//  CRCCalculationTests.m
//  XADMasterTests
//
//  Created by Taykalo on 12/21/18.
//

#import <XCTest/XCTest.h>
#import "../CRC.h"

typedef struct XADCRCTestsSUT {
    uint8_t * buffer;
} XADCRCTestsSUT;

@interface CRCCalculationTests : XCTestCase

@end

@implementation CRCCalculationTests

- (void)testFastCRCCalculation {
    int bufSize = 0x1000000;
    XADCRCTestsSUT sut = [self _sutWithBufferSize:bufSize];
    uint32_t originalCRC = XADCalculateCRC(0xFFFFFFFF, sut.buffer, bufSize, XADCRCTable_edb88320);
    uint32_t fastCRC = XADCalculateCRCFast(0xFFFFFFFF, sut.buffer, bufSize, XADCRCTable_sliced16_edb88320);
    XCTAssertEqual(originalCRC, fastCRC);
    
    [self _free:sut];
}

- (XADCRCTestsSUT)_sutWithBufferSize:(off_t)bufferSize {
    uint8_t * buffer = malloc(bufferSize);
    uint8_t * p = buffer;
    for (int i = 0; i < bufferSize; i ++, p++ ) {
        *p = arc4random();
    }
    return (XADCRCTestsSUT){
        buffer,
    };
}

- (void)_free:(XADCRCTestsSUT)sut {
    free(sut.buffer);
}


@end
