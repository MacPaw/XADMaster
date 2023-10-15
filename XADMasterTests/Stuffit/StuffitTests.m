
#import <XCTest/XCTest.h>
#include <objc/NSObject.h>
#import "../../CSHandle.h"
#import "../../CSMemoryHandle.h"
#import "../../XADWARCParser.h"
#import "../../XADSimpleUnarchiver.h"

@interface XADUnarchiverDelegate : NSObject

@property (nonatomic, assign) BOOL extractionFailed;
@property (nonatomic, assign) XADError error;
@end

@interface XADStuffitTests : XCTestCase
@property (nonatomic, strong) XADUnarchiverDelegate * delegate;
@property (nonatomic, strong) NSURL *tempDirURL;
@end


@implementation XADUnarchiverDelegate

-(void)simpleUnarchiver:(XADSimpleUnarchiver *)unarchiver didExtractEntryWithDictionary:(NSDictionary *)dict to:(NSString *)path error:(XADError)error
{
    if (error != XADNoError) {
        _extractionFailed = YES;
        _error = error;
    }
}

@end

@implementation XADStuffitTests


- (void)setUp {
    [super setUp];
    // Create temp directory
    NSString *tempDirName = [NSString stringWithFormat:@"%@StuffitTests-%@", NSTemporaryDirectory(), [[NSUUID UUID] UUIDString]];
    self.tempDirURL = [NSURL fileURLWithPath:tempDirName isDirectory:YES];
    [[NSFileManager defaultManager] createDirectoryAtURL:self.tempDirURL withIntermediateDirectories:YES attributes:nil error:nil];
    self.delegate = [XADUnarchiverDelegate new];
}

- (void)tearDown {
    // Remove temp directory
    [[NSFileManager defaultManager] removeItemAtURL:self.tempDirURL error:nil];
    [super tearDown];
}

- (void)testArchiveCanBeExtractedWithLessThan8CharactersInPassword
{
    NSURL * fixtureURL = [[NSBundle bundleForClass:[XADStuffitTests class]]
        URLForResource:@"1234567" withExtension:@"sit.bin" subdirectory:@"StuffitFixtures"];
    XCTAssertNotNil(fixtureURL, @"Could not find fixture file");
    
    XADError simpleUnarchiverError;
    XADSimpleUnarchiver * unarchiver = [XADSimpleUnarchiver simpleUnarchiverForPath: fixtureURL.path error:&simpleUnarchiverError];
    
    XCTAssertEqual(simpleUnarchiverError, XADNoError, @"Error creation: %@", [XADException describeXADError:simpleUnarchiverError]);
    XCTAssertNotNil(unarchiver);

    [unarchiver setDelegate:self.delegate];
    [unarchiver setPassword:@"1234567"];
    [unarchiver setDestination:self.tempDirURL.path];

    XADError parseError = [unarchiver parse];
    XCTAssertEqual(parseError, XADNoError, @"Parse error: %@", [XADException describeXADError:parseError]);

    XADError error = [unarchiver unarchive];
    
    XCTAssertEqual(error, XADNoError, @"Error unarchiving: %@", [XADException describeXADError:error]);
    XCTAssertFalse(_delegate.extractionFailed, @"Extraction failed: %@", [XADException describeXADError:_delegate.error]);
        
}

- (void)testArchiveCanBeExtractedWithMoreThan8CharactersInPassword
{
    NSURL * fixtureURL = [[NSBundle bundleForClass:[XADStuffitTests class]]
        URLForResource:@"123456789012" withExtension:@"sit.bin" subdirectory:@"StuffitFixtures"];
    XCTAssertNotNil(fixtureURL, @"Could not find fixture file");
    
    XADError simpleUnarchiverError;
    XADSimpleUnarchiver * unarchiver = [XADSimpleUnarchiver simpleUnarchiverForPath: fixtureURL.path error:&simpleUnarchiverError];
    
    XCTAssertEqual(simpleUnarchiverError, XADNoError, @"Error creation: %@", [XADException describeXADError:simpleUnarchiverError]);
    XCTAssertNotNil(unarchiver);

    [unarchiver setDelegate:self.delegate];
    [unarchiver setPassword:@"123456789012"];
    [unarchiver setDestination:self.tempDirURL.path];

    XADError parseError = [unarchiver parse];
    XCTAssertEqual(parseError, XADNoError, @"Parse error: %@", [XADException describeXADError:parseError]);

    XADError error = [unarchiver unarchive];
    
    XCTAssertEqual(error, XADNoError, @"Error unarchiving: %@", [XADException describeXADError:error]);
    XCTAssertFalse(_delegate.extractionFailed, @"Extraction failed: %@", [XADException describeXADError:_delegate.error]);
        
}

@end
