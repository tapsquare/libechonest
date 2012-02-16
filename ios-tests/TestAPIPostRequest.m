//
//  TestAPIPostRequest.m
//  libechonest
//
//  Created by Art Gillespie on 3/15/11. art@tapsquare.com
//

#import "TestAPIPostRequest.h"
#import "tests.h"
#import "ENAPI.h"

//#define ENABLE_LONG_RUNNING_TESTS

@implementation TestAPIPostRequest

- (void)setUp {
    [ENAPI initWithApiKey:TEST_API_KEY];
    NSBundle *bundle = [NSBundle bundleWithIdentifier:@"com.echonest.libechonest.tests"];
    testMp3Path = [[[bundle URLForResource:@"test" withExtension:@"mp3"] path] retain];
}

- (void)tearDown {
    [testMp3Path release];
}

- (void)testTrackUpload {    
    /**
     * TODO: [alg] This test takes a long time, so we disable them. Be sure to run it
     * now and then. To enable just #define ENABLE_LONG_RUNNING_TESTS
     */
#ifdef ENABLE_LONG_RUNNING_TESTS
    ENAPIPostRequest *request = [ENAPIPostRequest trackUploadRequestWithFile:testMp3Path];
    STAssertNotNil(request, @"request shouldn't be nil");
    [request startSynchronous];
    if (request.error)
        STFail(@"Request error not nil: %@", request.error);
    NSDictionary *track = [request.response valueForKeyPath:@"response.track"];
    STAssertTrue([[track valueForKey:@"artist"] isEqualToString:@"Tycho"], @"Expected artist == tycho : %@", [track valueForKey:@"artist"]);
#endif
}

- (void)testTrackAnalyzeWithFile{
    /**
     * TODO: [alg] This test takes a long time so we disable them. Be sure to run it
     * occasionally. To enable just #define ENABLE_LONG_RUNNING_TESTS
     */
#ifdef ENABLE_LONG_RUNNING_TESTS
    ENAPIPostRequest *request = [ENAPIPostRequest trackAnalyzeRequestWithFile:testMp3Path];
    STAssertNotNil(request, @"request shouldn't be nil");
    [request startSynchronous];
    if (request.error)
        STFail(@"Request error not nil: %@", request.error);
    NSDictionary *track = [request.response valueForKeyPath:@"response.track"];
    STAssertTrue([[track valueForKey:@"artist"] isEqualToString:@"Tycho"], @"Expected artist == tycho : %@", [track valueForKey:@"artist"]);
#endif
}

- (void)testTrackAnalyzeWithTrackId {
    /**
     * TODO: [alg] This test takes a long time so we disable them. Be sure to run it
     * occasionally. To enable just #define ENABLE_LONG_RUNNING_TESTS
     */
#ifdef ENABLE_LONG_RUNNING_TESTS
    ENAPIPostRequest *request = [ENAPIPostRequest trackAnalyzeRequestWithId:@"TRYRXSE12EBCE628F1"];
    STAssertNotNil(request, @"request shouldn't be nil");
    [request startSynchronous];
    if (request.error)
        STFail(@"Request error not nil: %@", request.error);
    NSDictionary *track = [request.response valueForKeyPath:@"response.track"];
    STAssertTrue([[track valueForKey:@"artist"] isEqualToString:@"Tycho"], @"Expected artist == tycho : %@", [track valueForKey:@"artist"]);
#endif
}

@end
