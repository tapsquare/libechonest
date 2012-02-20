//
//  ENAPIRequest.m
//  libechonest
//
//  Copyright (c) 2011, tapsquare, llc. (http://www.tapsquare.com, art@tapsquare.com)
//  All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions are met:
//
//   * Redistributions of source code must retain the above copyright
//     notice, this list of conditions and the following disclaimer.
//   * Redistributions in binary form must reproduce the above copyright
//     notice, this list of conditions and the following disclaimer in the
//     documentation and/or other materials provided with the distribution.
//   * Neither the name of the tapsquare, llc nor the names of its contributors
//     may be used to endorse or promote products derived from this software
//     without specific prior written permission.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
//  ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
//  WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
//  DISCLAIMED. IN NO EVENT SHALL TAPSQUARE, LLC. BE LIABLE FOR ANY
//  DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
//  (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
//  LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
//  ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
//  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
//  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#import "ENAPIRequest.h"

#import "ENAPI_utils.h"
#import "ENAPI.h"
#import "ENSigner.h"
#import "NSObject+JSON.h"
#import <Foundation/NSURLRequest.h>
#import <Foundation/NSURLConnection.h>

@interface ENAPIRequest()

- (void)_prepareToStart;
- (NSString *)_constructURL;
- (NSInteger)_generateTimestamp;
- (NSString *)_generateNonce:(NSInteger)timestamp;
- (NSString *)_constructBaseSignatureForOAuth;
- (void)_includeOAuthParams;
- (void)_requestFinished;
- (void)_requestFailed;

@property (retain) NSHTTPURLResponse *internalResponse;
@property (retain) NSError *internalError;
@property (retain) NSMutableURLRequest *request;
@property (retain) NSMutableData *receivedData;
@property (retain,readwrite) NSMutableDictionary *params;
@property (retain) NSDictionary *_responseDict;
@property (retain) NSString *_responseString;
@property (assign) BOOL isAPIRequest;
@property (retain) NSString *analysisURL;
@end

@implementation ENAPIRequest

@synthesize delegate, response, _responseDict, _responseString, endpoint;
@synthesize request, params;
@synthesize userInfo;
@synthesize isAPIRequest;
@synthesize analysisURL;
@synthesize connection = _connection;
@synthesize receivedData = _receivedData;
@synthesize complete = _complete;
@synthesize internalResponse = _internalResponse;
@synthesize internalError = _internalError;

+ (ENAPIRequest *)requestWithEndpoint:(NSString *)endpoint_ {
    return [[[ENAPIRequest alloc] initWithEndpoint:endpoint_] autorelease];
}

+ (ENAPIRequest *)requestWithAnalysisURL:(NSString *)url_ {
    return [[[ENAPIRequest alloc] initWithAnalysisURL:url_] autorelease];
}

- (ENAPIRequest *)initWithEndpoint:(NSString *)endpoint_ {
    self = [super init];
    if (self) {
        CHECK_API_KEY
        self.isAPIRequest = YES;
        endpoint = [endpoint_ retain];
        self.params = [NSMutableDictionary dictionaryWithCapacity:4];
        [self.params setValue:[ENAPI apiKey] forKey:@"api_key"];
        [self.params setValue:@"json" forKey:@"format"];
        if ([ENAPI isSecuredEndpoint:endpoint]) {
            // fail fast is consumer key & secret missing
            CHECK_OAUTH_KEYS
        }
    }
    return self;
}

- (ENAPIRequest *)initWithAnalysisURL:(NSString *)url {
    self = [super init];
    if (self) {
        CHECK_API_KEY
        self.isAPIRequest = NO;
        self.analysisURL = url;
        self.params = [NSMutableDictionary dictionaryWithCapacity:4];
    }
    return self;    
}

- (void)dealloc {
    [params release];
    [request release];
    [_responseDict release];
    [endpoint release];
    [userInfo release];
    [analysisURL release];
    [_connection release];
    [_internalError release];
    [_receivedData release];
    [super dealloc];
}

- (void)startSynchronous {
    [self _prepareToStart];

    NSData *data = [NSURLConnection sendSynchronousRequest:self.request
                                         returningResponse:&_internalResponse
                                                     error:&_internalError];

    _responseString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

    if (nil == _internalError) {
        [self _requestFinished];
    } else {
        [self _requestFailed];
    }
}

- (void)startAsynchronous {
    [self startAsynchronousAndScheduleInRunLoop:[NSRunLoop currentRunLoop]
                                        forMode:NSDefaultRunLoopMode];
}

- (void)startAsynchronousAndScheduleInRunLoop:(NSRunLoop *)runLoop forMode:(NSString *)mode {
    [self _prepareToStart];

    self.connection = [NSURLConnection connectionWithRequest:self.request
                                                 delegate:self];
    [self.connection scheduleInRunLoop:runLoop forMode:mode];
    [self.connection start];
}

- (void)setValue:(id)value forParameter:(NSString *)param {
    [self.params setValue:value forKey:param];
}

- (void)setIntegerValue:(NSInteger)value forParameter:(NSString *)param {
    [self.params setValue:[NSNumber numberWithInteger:value] forKey:param];
}

- (void)setFloatValue:(float)value forParameter:(NSString *)param {
    [self.params setValue:[NSNumber numberWithFloat:value] forKey:param];
}

- (void)setBoolValue:(BOOL)value forParameter:(NSString *)param {
    [self.params setValue:[NSNumber numberWithBool:value] forKey:param];
}

- (void)cancel {
    [self.connection cancel];
}

#pragma mark - Properties

- (NSDictionary *)response {
    if (nil == _responseDict) {
        NSDictionary *dict = [self.responseString JSONValue];
        _responseDict = [dict retain];
    }
    return _responseDict;
}

- (NSString *)responseString {
    return _responseString;
}

- (NSInteger)responseStatusCode {
    return [self.internalResponse statusCode];
}

- (NSError *)error {
    return self.internalError;
}

- (NSUInteger)echonestStatusCode {
    return [[self.response valueForKeyPath:@"response.status.code"] intValue];
}

- (NSString *)echonestStatusMessage {
    return [self.response valueForKeyPath:@"response.status.message"];
}

- (NSURL *)requestURL {
    return [self.request URL];
}

#pragma mark - NSURLConnection Delegate Methods

- (void) connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response_ {
    self.internalResponse = (NSHTTPURLResponse *)response_;
    self.receivedData = [[[NSMutableData alloc] initWithLength:0] autorelease];
}

- (void) connection:(NSURLConnection *)connection didReceiveData:(NSData *)data_ {
    [self.receivedData appendData:data_];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error_ {
    _complete = YES;
    self.internalError = error_;
    // we're done with mutable data holder
    [_receivedData release];
    // deliver the bad news...
    [self _requestFailed];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    _complete = YES;

    _responseString = [[NSString alloc] initWithData:self.receivedData
                                            encoding:NSUTF8StringEncoding];
    // we're done with mutable data holder
    [_receivedData release];

    [self _requestFinished];
    // Should we release the connection here? [AJL]
}

#pragma mark - Private Methods

- (void)_requestFinished {
    if ([delegate respondsToSelector:@selector(requestFinished:)]) {
        [delegate requestFinished:self];
    }
}

- (void)_requestFailed {
    if([delegate respondsToSelector:@selector(requestFailed:)]) {
        [delegate requestFailed:self];
    }
}

- (void)_prepareToStart {
    if (nil != self.analysisURL) {
        self.request = [NSURLRequest requestWithURL:[NSURL URLWithString:self.analysisURL]];
    } else {
        // add OAuth parameter if we're hitting a secured endpoint
        if ([ENAPI isSecuredEndpoint:self.endpoint]) {
            [self _includeOAuthParams];
        }
        self.request = [NSURLRequest requestWithURL:[NSURL URLWithString:[self _constructURL]]];
    }
}

- (NSString *)_constructURL {
    NSString *ret = [NSString stringWithFormat:@"%@%@?%@", ECHONEST_API_URL, self.endpoint, [self.params enapi_queryString]];
    return ret;
}

- (NSInteger)_generateTimestamp {
    NSDate *now = [[NSDate alloc] init];
    NSTimeInterval timestamp = [now timeIntervalSince1970];
    [now release];
    return (NSInteger)timestamp;
}

- (NSString *)_generateNonce:(NSInteger)timestamp {
    NSString *tmp = [[NSString alloc] initWithFormat:@"%d", timestamp];
    NSData *nonceData = [tmp dataUsingEncoding:NSUTF8StringEncoding];
    NSString *nonce = [nonceData enapi_MD5];
    [tmp release];
    return nonce;
}

- (NSString *)_constructBaseSignatureForOAuth {
    NSString *queryString = [self.params enapi_queryString];

    NSString *base_signature = [NSString stringWithFormat:@"GET&%@%@&%@",
                                ENEscapeStringForURL(ECHONEST_API_URL),
                                ENEscapeStringForURL(self.endpoint),
                                ENEscapeStringForURL(queryString)];

    NSString *signature = [ENSigner signText:base_signature
                            WithKeyAndEncode:[ENAPI sharedSecret]];

    return signature;
}

- (void)_includeOAuthParams {
    NSTimeInterval timestamp = [self _generateTimestamp];
    NSString *nonce = [self _generateNonce:timestamp];

    [self setValue:[ENAPI consumerKey] forParameter:@"oauth_consumer_key"];
    [self setIntegerValue:(NSInteger)timestamp  forParameter:@"oauth_timestamp"];
    [self setValue:@"HMAC-SHA1" forParameter:@"oauth_signature_method"];
    [self setValue:nonce forParameter:@"oauth_nonce"];
    [self setValue:@"1.0" forParameter:@"oauth_version"];

    NSString *signature = [self _constructBaseSignatureForOAuth];

    [self setValue: signature forParameter:@"oauth_signature"];
}

@end
