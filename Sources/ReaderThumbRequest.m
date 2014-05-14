//
//	ReaderThumbRequest.m
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

#import "ReaderThumbRequest.h"
#import "ReaderThumbView.h"
#import "ReaderThumbCache.h"
#import "CGPDFDocument.h"


@interface ReaderThumbRequest ()

@property (nonatomic, readwrite, strong) NSURL *fileURL;
@property (nonatomic, readwrite, copy) NSString *guid;
@property (nonatomic, readwrite, copy) NSString *password;
@property (nonatomic, readwrite, copy) NSString *cacheKey;
@property (nonatomic, readwrite, copy) NSString *thumbName;
@property (nonatomic, readwrite, strong) ReaderThumbView *thumbView;
@property (nonatomic, readwrite) NSUInteger targetTag;
@property (nonatomic, readwrite) NSInteger thumbPage;
@property (nonatomic, readwrite) CGSize thumbSize;
@property (nonatomic, readwrite) CGFloat scale;

@end


@implementation ReaderThumbRequest

#pragma mark Properties

@synthesize guid = _guid;
@synthesize fileURL = _fileURL;
@synthesize password = _password;
@synthesize thumbView = _thumbView;
@synthesize thumbPage = _thumbPage;
@synthesize thumbSize = _thumbSize;
@synthesize thumbName = _thumbName;
@synthesize targetTag = _targetTag;
@synthesize cacheKey = _cacheKey;
@synthesize scale = _scale;


+ (id)forView:(ReaderThumbView *)view fileURL:(NSURL *)url password:(NSString *)phrase guid:(NSString *)guid page:(NSInteger)page size:(CGSize)size
{
	return [[ReaderThumbRequest alloc] initWithView:view fileURL:url password:phrase guid:guid page:page size:size];
}


/**
 *	Instantiates a new object with the given information. If "guid" is nil, creates a string based on the file URL and uses this as identifier.
 */
- (id)initWithView:(ReaderThumbView *)view fileURL:(NSURL *)url password:(NSString *)phrase guid:(NSString *)guid page:(NSInteger)page size:(CGSize)size
{
	if ((self = [super init])) {
		_thumbPage = page;
		_thumbSize = size;
		self.fileURL = url;
		self.password = phrase;
		self.guid = guid ? guid : [[url relativeString] stringByTrimmingCharactersInSet:[[NSCharacterSet alphanumericCharacterSet] invertedSet]];
		self.thumbName = [NSString stringWithFormat:@"%07ld-%04.0fx%04.0f", (long)page, size.width, size.height];
		self.cacheKey = [NSString stringWithFormat:@"%@+%@", _thumbName, _guid];
		
		self.thumbView = view;
		_targetTag = [_cacheKey hash];
		_thumbView.targetTag = _targetTag;
		_scale = [[UIScreen mainScreen] scale];
	}
	
	return self;
}



#pragma mark - Actions
/**
 *	Uses the request to fetch the cached thumbnail, creating it on a background thread if necessary, and shows it in the given view
 */
- (void)process
{
	UIImage *thumb = [[ReaderThumbCache sharedInstance] thumbRequest:self priority:YES];
	if (_thumbView.superview && thumb) {
		[_thumbView showImage:thumb];
	}
}

- (void)processWithoutPriority
{
	UIImage *thumb = [[ReaderThumbCache sharedInstance] thumbRequest:self priority:NO];
	if (_thumbView.superview && thumb) {
		[_thumbView showImage:thumb];
	}
}


@end
