//
//	ReaderThumbQueue.m
//	Reader v2.5.4
//
//	Created by Julius Oklamcak on 2011-09-01.
//	Copyright © 2011-2012 Julius Oklamcak. All rights reserved.
//
//	Permission is hereby granted, free of charge, to any person obtaining a copy
//	of this software and associated documentation files (the "Software"), to deal
//	in the Software without restriction, including without limitation the rights to
//	use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
//	of the Software, and to permit persons to whom the Software is furnished to
//	do so, subject to the following conditions:
//
//	The above copyright notice and this permission notice shall be included in all
//	copies or substantial portions of the Software.
//
//	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
//	OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
//	WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
//	CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

#import "ReaderThumbQueue.h"
#import "CGPDFDocument.h"

@implementation ReaderThumbQueue

//#pragma mark Properties

//@synthesize ;

#pragma mark ReaderThumbQueue class methods

+ (ReaderThumbQueue *)sharedInstance
{
	static dispatch_once_t predicate = 0;
	static ReaderThumbQueue *object = nil;
	dispatch_once(&predicate, ^{ object = [self new]; });
	
	return object;
}

#pragma mark ReaderThumbQueue instance methods

- (id)init
{
	if ((self = [super init])) {
		loadQueue = [NSOperationQueue new];
		[loadQueue setName:@"ReaderThumbLoadQueue"];
		[loadQueue setMaxConcurrentOperationCount:1];
		
		workQueue = [NSOperationQueue new];
		[workQueue setName:@"ReaderThumbWorkQueue"];
		[workQueue setMaxConcurrentOperationCount:1];
	}
	return self;
}

- (void)dealloc
{
	loadQueue = nil;
	workQueue = nil;
}

- (void)addLoadOperation:(NSOperation *)operation
{
	DXLog(@"");
	if ([operation isKindOfClass:[ReaderThumbOperation class]]) {
		[loadQueue addOperation:operation];
	}
}

- (void)addWorkOperation:(NSOperation *)operation
{
	DXLog(@"");
	if ([operation isKindOfClass:[ReaderThumbOperation class]]) {
		[workQueue addOperation:operation];
	}
}

- (void)cancelOperationsWithGUID:(NSString *)guid
{
	DXLog(@"");
	[loadQueue setSuspended:YES];
	[workQueue setSuspended:YES];
	
	for (ReaderThumbOperation *operation in loadQueue.operations) {
		if ([operation isKindOfClass:[ReaderThumbOperation class]]) {
			if ([operation.guid isEqualToString:guid]) [operation cancel];
		}
	}
	
	for (ReaderThumbOperation *operation in workQueue.operations) {
		if ([operation isKindOfClass:[ReaderThumbOperation class]]) {
			if ([operation.guid isEqualToString:guid]) [operation cancel];
		}
	}
	
	[workQueue setSuspended:NO];
	[loadQueue setSuspended:NO];
}

- (void)cancelAllOperations
{
	DXLog(@"");
	[loadQueue cancelAllOperations];
	[workQueue cancelAllOperations];
}

@end

#pragma mark -

//
//	ReaderThumbOperation class implementation
//

@interface ReaderThumbOperation ()

@property (nonatomic, readwrite, copy) NSString *guid;

@end


@implementation ReaderThumbOperation

@synthesize guid;

#pragma mark ReaderThumbOperation instance methods

- (id)initWithGUID:(NSString *)aGuid
{
	if ((self = [super init])) {
		self.guid = aGuid;
	}
	return self;
}


@end
