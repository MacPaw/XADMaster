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

- (void)testFastCRCCalculationMatchesSlowCRCForDeterministicRegressionBuffers {
    uint32_t words[128];
    uint8_t *buffer = (uint8_t *)words;

    // Keep this deterministic so the XCTest and s390x regression harness cover
    // the same data shapes and failures.
    for (size_t i = 0; i < (sizeof(words) / sizeof(words[0])); i++) {
        words[i] = (uint32_t)(0x9E3779B9u * (uint32_t)(i + 1u)) ^ (uint32_t)(0xA5A5A5A5u + (uint32_t)i);
    }

    [self _assertFastCRCMatchesSlowCRCForBuffer:buffer length:64 label:@"exact-fast-block"];
    [self _assertFastCRCMatchesSlowCRCForBuffer:buffer length:65 label:@"fast-block-plus-tail"];
    [self _assertFastCRCMatchesSlowCRCForBuffer:buffer length:127 label:@"multi-block-odd-tail"];
    [self _assertFastCRCMatchesSlowCRCForBuffer:buffer length:(int)sizeof(words) label:@"full-buffer"];
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

- (void)_assertFastCRCMatchesSlowCRCForBuffer:(const uint8_t *)buffer length:(int)length label:(NSString *)label {
    uint32_t slowCRC = XADCalculateCRC(0xFFFFFFFFu, buffer, length, XADCRCTable_edb88320);
    uint32_t fastCRC = XADCalculateCRCFast(0xFFFFFFFFu, buffer, length, XADCRCTable_sliced16_edb88320);

    XCTAssertEqual(slowCRC, fastCRC, @"CRC mismatch for %@", label);
}

@end
