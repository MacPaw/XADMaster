//
//  XADZippedBzip2LeakTests.m
//  XADMasterTests
//
//  Created by aure on 03/02/2022.
//

#import <XCTest/XCTest.h>

#import "../CSMemoryHandle.h"
#import "../XADZipParser.h"
#import "../XADBzip2Parser.h"


@interface XADZippedBzip2LeakTests : XCTestCase

@end

@implementation XADZippedBzip2LeakTests

- (void)testNoLeak {

	NSString *path = [[NSBundle bundleForClass:[self class]] pathForResource:@"eicar" ofType:@"bz"];

	XADError error;
	XADArchiveParser *parser = [XADArchiveParser archiveParserForPath:path error:&error];
	NSLog(@"Parser for eicar.bz: %@", parser);
    XADHandle *handle = [parser handleForEntryWithDictionary:[parser properties] wantChecksum:NO];
	NSLog(@"handle eicar.bz: %@", handle);

	// to get the total size, just seek to end and reset offset to 0. Should be 68
	[handle seekToEndOfFile];
	off_t size = [handle offsetInFile];
	[handle seekToFileOffset:0];

	NSData *data = [handle readDataOfLengthAtMost:(int)size];
	NSLog(@"read data:%@",data);

	sleep(10); // to ensure leaks analysis occured in Instruments.
}



@end
