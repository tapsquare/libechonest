//
//  ENAPIPostRequest.m
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

#import "ENAPIPostRequest.h"
#import "ENAPI.h"
#import "ENAPI_utils.h"
#import "ENAPIPostRequest.h"
#import "NSObject+JSON.h"

@interface ENAPIPostRequest() 
@property (retain) NSMutableURLRequest *request;
@property (retain) NSDictionary *_responseDict;
@property (retain) NSURLConnection *connection;
@property (retain) NSHTTPURLResponse *internalResponse;
@property (retain) NSMutableData *receivedData;
@property (retain) NSString *responseString;
@property (retain) NSError *internalError;
@property (retain) NSMutableDictionary *postValues;
@property (retain) NSMutableDictionary *fileData;

-(void)_preparePostBody;
-(void)_requestFailed;
-(void)_requestFinished;
@end

@implementation ENAPIPostRequest
// public properties
@synthesize delegate, request, userInfo;
// private properties
@synthesize  _responseDict;
@synthesize responseString = _responseString;
@synthesize receivedData = _receivedData;
@synthesize internalResponse = _internalResponse;
@synthesize internalError = _internalError;
@synthesize postValues = _postValues;
@synthesize fileData = _fileData;
@synthesize connection = _connection;

- (id)initWithURL:(NSURL *)url {
    
    self = [super init];
    if (self) {
        self.request = [NSURLRequest requestWithURL:url];

        [self.request setHTTPMethod:@"POST"];
        [self.request setTimeoutInterval:180];
        [self setPostValue:[ENAPI apiKey] forKey:@"api_key"];
    }
    return self;
}

- (void) dealloc {
    delegate = nil;
    [request release];
    [_responseDict release];
    [userInfo release];
    [_responseString release];
    [_internalError release];
    [_internalResponse release];
    [_postValues release];
    [_fileData release];
    [_connection release];
    [super dealloc];
}

+ (ENAPIPostRequest *)requestWithURL:(NSURL *)url {
    return [[[ENAPIPostRequest alloc] initWithURL:url] autorelease];
    
}

+ (ENAPIPostRequest *)trackUploadRequestWithFile:(NSString *)filePath {
    CHECK_API_KEY
    NSString *urlString = [NSString stringWithFormat:@"%@track/upload", ECHONEST_API_URL];
    NSURL *url = [NSURL URLWithString:urlString];
    ENAPIPostRequest *postRequest = [ENAPIPostRequest requestWithURL:url];
    [postRequest setFile:filePath forKey:@"track"];
    NSString *ext = [[filePath pathExtension] lowercaseString];
    [postRequest setPostValue:ext forKey:@"filetype"];
    return postRequest;
}

+ (ENAPIPostRequest *)trackAnalyzeRequestWithFile:(NSString *)filePath {
    CHECK_API_KEY
    // we need the md5 of the file
    NSData *fileData = [NSData dataWithContentsOfFile:filePath];
    NSString *md5 = [fileData enapi_MD5];
    return [ENAPIPostRequest trackAnalyzeRequestWithMD5:md5];
}

+ (ENAPIPostRequest *)trackAnalyzeRequestWithId:(NSString *)trackid {
    CHECK_API_KEY
    NSString *urlString = [NSString stringWithFormat:@"%@track/analyze", ECHONEST_API_URL];
    NSURL *url = [NSURL URLWithString:urlString];
        
    ENAPIPostRequest *postRequest = [ENAPIPostRequest requestWithURL:url];
    [postRequest setPostValue:trackid forKey:@"id"];
    return postRequest;    
}

+ (ENAPIPostRequest *)trackAnalyzeRequestWithMD5:(NSString *)md5 {
    CHECK_API_KEY
    NSString *urlString = [NSString stringWithFormat:@"%@track/analyze", ECHONEST_API_URL];
    NSURL *url = [NSURL URLWithString:urlString];
    
    ENAPIPostRequest *postRequest = [ENAPIPostRequest requestWithURL:url];
    [postRequest setPostValue:md5 forKey:@"md5"];
    return postRequest;    
}

+ (ENAPIPostRequest *)catalogCreateWithName:(NSString *)name type:(NSString *)type {
    CHECK_API_KEY
    NSString *urlString = [NSString stringWithFormat:@"%@catalog/create", ECHONEST_API_URL];
    NSURL *url = [NSURL URLWithString:urlString];
    
    ENAPIPostRequest *postRequest = [ENAPIPostRequest requestWithURL:url];
    [postRequest setPostValue:name forKey:@"name"];
    [postRequest setPostValue:type forKey:@"type"];
    return postRequest;    
}

+ (ENAPIPostRequest *)catalogDeleteWithID:(NSString *)ID {
    CHECK_API_KEY
    NSString *urlString = [NSString stringWithFormat:@"%@catalog/delete", ECHONEST_API_URL];
    NSURL *url = [NSURL URLWithString:urlString];
    
    ENAPIPostRequest *postRequest = [ENAPIPostRequest requestWithURL:url];
    [postRequest setPostValue:ID forKey:@"id"];
    return postRequest;        
}

+ (ENAPIPostRequest *)catalogUpdateWithID:(NSString *)ID data:(NSString *)json {
    CHECK_API_KEY
    NSString *urlString = [NSString stringWithFormat:@"%@catalog/update", ECHONEST_API_URL];
    NSURL *url = [NSURL URLWithString:urlString];
    
    ENAPIPostRequest *postRequest = [ENAPIPostRequest requestWithURL:url];
    [postRequest setPostValue:ID forKey:@"id"];
    [postRequest setPostValue:json forKey:@"data"];
    [postRequest setPostValue:@"json" forKey:@"json"];
    return postRequest;            
}

- (void)setPostValue:(NSObject *)value forKey:(NSString *)key {
    if (nil == _postValues) {
        self.postValues = [[NSMutableDictionary alloc] initWithCapacity:10];
    }
    [self.postValues setObject:value forKey:key];
}

- (void)setFile:(NSString *)path forKey:(NSString *)key {
    if (nil == _fileData) {
        self.fileData = [[NSMutableDictionary alloc] initWithCapacity:5];
    }
    NSString *filename = [path lastPathComponent];
    NSDictionary *fileInfo = [NSDictionary dictionaryWithObjectsAndKeys:path, @"path",
                               filename, @"filename", key, @"key", nil];
    [self.fileData setObject:fileInfo forKey:key];
}

- (void)startSynchronous {
    [self retain]; // let's make sure we're still around when the network call returns

    [self _preparePostBody];

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
    [self retain]; // let's make sure we're still around when the network call returns

    [self _preparePostBody];

    self.connection = [NSURLConnection connectionWithRequest:self.request
                                                    delegate:self];

    // Schedule in the RunLoop
    [self.connection start];
}

- (void)_prepareFormValuesForPostBody:(NSMutableData *)postBody withBoundary:(NSString *)boundary {
    NSString *endBoundary = [NSString stringWithFormat:@"\r\n--%@\r\n",boundary];
	NSUInteger idx=0;
	for (NSString *key in [self.postValues allKeys]) {
        NSString *valHeading = [NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"\r\n\r\n",key];
		[postBody appendData:[valHeading dataUsingEncoding:NSUTF8StringEncoding]];
		[postBody appendData:[[self.postValues objectForKey:key] dataUsingEncoding:NSUTF8StringEncoding]];

        idx++;

        // if processing value and it's not the last one, add delimiter
		if (idx != [self.postValues count] || [self.fileData count] > 0) {
			[postBody appendData:[endBoundary dataUsingEncoding:NSUTF8StringEncoding]];
		}
	}
}

- (void)_prepareFileDataForPostBody:(NSMutableData *)postBody withBoundary:(NSString *)boundary {
    NSString *endBoundary = [NSString stringWithFormat:@"\r\n--%@\r\n",boundary];
	NSUInteger idx=0;
    for (NSDictionary *fileInfo in [self.fileData allValues]) {
        NSString *valHeading = [NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"; filename=\"%@\"\r\n",
                                [fileInfo objectForKey:@"key"], [fileInfo objectForKey:@"filename"]];
        [postBody appendData:[valHeading dataUsingEncoding:NSUTF8StringEncoding]];
        [postBody appendData:[NSData dataWithContentsOfFile:[fileInfo objectForKey:@"path"]]];

        idx++;

        // if processing value and it's not the last one, add delimiter
        if (idx != [self.fileData count]) {
            [postBody appendData:[endBoundary dataUsingEncoding:NSUTF8StringEncoding]];
        }
    }
}

- (void)_preparePostBody {
    NSString *charset = (NSString *)CFStringConvertEncodingToIANACharSetName(CFStringConvertNSStringEncodingToEncoding(NSUTF8StringEncoding));
    NSString *boundary = @"---------------------0x520OlDPuEbLo19120214";
    NSString *contentType = [NSString stringWithFormat:@"multipart/form-data; charset=%@; boundary=%@",charset,boundary];
    [self.request addValue:contentType forHTTPHeaderField: @"Content-Type"];

    NSMutableData *postBody = [NSMutableData dataWithLength:0];

    [self _prepareFormValuesForPostBody:postBody withBoundary:boundary];
    [self _prepareFileDataForPostBody:postBody withBoundary:boundary];

    NSLog(@"POST Body: \n%@", [[[NSString alloc] initWithData:postBody
                                                     encoding:NSUTF8StringEncoding] autorelease]);

    [postBody appendData:[[NSString stringWithFormat:@"\r\n--%@--\r\n",boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    [request setHTTPBody:postBody];


}

#pragma mark - NSURLConnectionDelegate

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    self.internalResponse = (NSHTTPURLResponse *)response;
    self.receivedData = [[[NSMutableData alloc] initWithLength:0] autorelease];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data_ {
    [self.receivedData appendData:data_];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error_ {
    self.internalError = error_;
    [_receivedData release];
    [self _requestFailed];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    _responseString = [[NSString alloc] initWithData:self.receivedData
                                            encoding:NSUTF8StringEncoding];
    [_receivedData release];
    [self _requestFinished];
}

#pragma mark - NSURLConnectionDataDelegate


- (void)connection:(NSURLConnection *)connection didSendBodyData:(NSInteger)bytesWritten
                                               totalBytesWritten:(NSInteger)totalBytesWritten
                                       totalBytesExpectedToWrite:(NSInteger)totalBytesExpectedToWrite {
    if ([self.delegate respondsToSelector:@selector(postRequest:didSendBytes:)]) {
        [(id<ENAPIPostRequestDelegate>)self.delegate postRequest:self didSendBytes:bytesWritten];
    }
    if ([self.delegate respondsToSelector:@selector(postRequest:uploadProgress:)]) {
        [(id<ENAPIPostRequestDelegate>)self.delegate postRequest:self uploadProgress:(float)totalBytesWritten/(float)totalBytesExpectedToWrite];
    }
}

#pragma mark - Private Methods

- (void)_requestFinished {
    if ([self.delegate respondsToSelector:@selector(postRequestFinished:)]) {
        [(id<ENAPIPostRequestDelegate>)self.delegate postRequestFinished:self];
    }
    [self release];
}

- (void)_requestFailed {
    if ([self.delegate respondsToSelector:@selector(postRequestFailed:)]) {
        [(id<ENAPIPostRequestDelegate>)self.delegate postRequestFailed:self];
    }
    [self release];
}

#pragma mark - Properties

- (NSDictionary *)response {
    if (nil == _responseDict) {
        NSDictionary *dict = [self.responseString JSONValue];
        _responseDict = [dict retain];
    }
    return _responseDict;
}

- (NSUInteger)responseStatusCode {
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
@end