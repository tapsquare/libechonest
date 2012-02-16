//
//  TestAsynchAPIRequest.m
//  libechonest
//
//  Created by Andrew Lenards on 2/15/12.
//

#import "TestAPIRequestResponseWithDelegate.h"
#import "ENAPI.h"
#import "tests.h"

static NSString *OAUTH_TIMESTAMP = @"oauth-timestamp";
static NSString *SANDBOX_LIST = @"sandbox-list";

@interface TestAPIRequestResponseWithDelegate ()

@property (retain) NSString *testCaseIdentifier;

- (BOOL)unexpectedFailureForRequests;

@end

@implementation TestAPIRequestResponseWithDelegate

@synthesize testCaseIdentifier = _tcId;

- (void)setUp {
    [super setUp];
    [ENAPI initWithApiKey:TEST_API_KEY];
}

- (void)tearDown {
    [_tcId release];

    [super tearDown];
}

- (BOOL)unexpectedFailureForRequests {
    return OAUTH_TIMESTAMP == self.testCaseIdentifier ||
            SANDBOX_LIST == self.testCaseIdentifier;
}

- (void)testOAuthTimestamp {
    self.testCaseIdentifier = OAUTH_TIMESTAMP;
    ENAPIRequest * req = [[ENAPIRequest alloc] initWithEndpoint:@"oauth/timestamp"];
    req.delegate = self;
    [req startSynchronous];
    // TODO: schedule this request on a runLoop to test asynch-callbacks
}

- (void)testSandboxAccess {
    // emi_open_collection
    ENAPIRequest * req = [[ENAPIRequest alloc] initWithEndpoint:@"sandbox/list"];

    [req setValue: @"emi_open_collection" forParameter:@"sandbox"];
    [req setIntegerValue:1 forParameter:@"results"];

    req.delegate = self;
    [req startSynchronous];
    // TODO: schedule this request on a runLoop to test asynch-callbacks
}

- (void)requestFinished:(ENAPIRequest *)request {
    if (OAUTH_TIMESTAMP == self.testCaseIdentifier) {
        NSUInteger statusCode = request.responseStatusCode;
        STAssertTrue(200 == statusCode, @"Expect a status code of 200, status code: %d ", statusCode);
        STAssertTrue([request.echonestStatusMessage isEqual: @"success"],
                     @"Expect an Echo Nest Status Message of _success_, msg: %@",
                     request.echonestStatusMessage);
        STAssertTrue(0 == request.echonestStatusCode,
                     @"Expect an Echo Nest Status Code of Zero, %d ",
                     request.echonestStatusCode);
        int timestamp = [[request.response valueForKeyPath:@"response.current_time"] intValue];
        NSDate *date = [[NSDate alloc] init];
        NSInteger now = (NSInteger)[date timeIntervalSince1970];
        [date release];

        NSInteger delta = now - timestamp;
        STAssertTrue(delta <= 30, @"Rough check to see resolution of timestamp");
    } else if (SANDBOX_LIST == self.testCaseIdentifier) {
        NSUInteger statusCode = request.responseStatusCode;
        STAssertTrue(200 == statusCode, @"Expect a status code of 200, status code: %d ", statusCode);
        STAssertTrue(@"success" == request.echonestStatusMessage,
                     @"Expect an Echo Nest Status Message of _success_, msg: %@",
                     request.echonestStatusMessage);
        STAssertTrue(0 == request.echonestStatusCode,
                     @"Expect an Echo Nest Status Code of Zero, %d ",
                     request.echonestStatusCode);

        NSArray *assets = [request.response valueForKeyPath:@"response.assets"];
        STAssertNotNil(assets, @"Expect assets listing to have at least one value");

        NSNumber *assetTotal = (NSNumber *)[request.response valueForKeyPath:@"response.total"];
        NSLog(@"Total Assets: %@", assetTotal);
        STAssertTrue(assetTotal > 0, @"Expect the asset total to be non-zero; total: %@", assetTotal);

        id asset = [assets objectAtIndex:0];
        NSLog(@"%@", asset);
        NSLog(@"%@", [asset class]);
        NSString *assetId = [asset valueForKeyPath:@"id"];
        STAssertNotNil(assetId, @"Expect the asset-id to be non-nil; asset-id: %@", assetId);
    }
}

- (void)requestFailed:(ENAPIRequest *)request {
    if ([self unexpectedFailureForRequests]) {
        // these test cases should NOT fail.
        STAssertTrue(NO, @"Expected request to success - test case %@ failed",
                     self.testCaseIdentifier);
        NSLog(@"HTTP Status Code: %d", request.responseStatusCode);
        NSLog(@"Request Error: %@", request.error);
        NSLog(@"Echo Nest Message: %@", request.echonestStatusMessage);
        NSLog(@"Echo Nest Status Code: %d", request.echonestStatusCode);
    }
}

@end