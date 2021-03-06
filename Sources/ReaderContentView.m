//
//	ReaderContentView.m
//	Reader v2.5.5
//
//	Created by Julius Oklamcak on 2011-07-01.
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

#import "ReaderConstants.h"
#import "ReaderContentView.h"
#import "ReaderContentPage.h"
#import "ReaderThumbCache.h"
#import "CGPDFDocument.h"

#import <QuartzCore/QuartzCore.h>


@interface ReaderContentView ()

@property (nonatomic, readwrite, strong) ReaderContentPage *contentPage;
@property (nonatomic, readwrite, strong) ReaderContentThumb *thumbView;
@property (nonatomic, readwrite, strong) UIView *containerView;

@end


@implementation ReaderContentView

#pragma mark Constants

#define ZOOM_LEVELS 3

#if READER_SHOW_SHADOWS
# define CONTENT_INSET 4.f
#else
# define CONTENT_INSET 0.f
#endif

#define PAGE_THUMB_LARGE 240
#define PAGE_THUMB_SMALL 144

#pragma mark Properties

@synthesize message, contentPage, thumbView, containerView;

#pragma mark - ReaderContentView functions

static inline CGFloat ZoomScaleThatFits(CGSize target, CGSize source)
{
	CGFloat w_scale = (target.width / source.width);
	CGFloat h_scale = (target.height / source.height);
	return ((w_scale < h_scale) ? w_scale : h_scale);
}

#pragma mark ReaderContentView instance methods

- (void)updateMinimumMaximumZoom
{
	CGRect targetRect = CGRectInset(self.bounds, CONTENT_INSET, CONTENT_INSET);
	CGFloat zoomScale = ZoomScaleThatFits(targetRect.size, contentPage.bounds.size);
	self.minimumZoomScale = zoomScale;
	self.maximumZoomScale = zoomScale * MAX(2, ZOOM_LEVELS);
}

- (id)initWithFrame:(CGRect)frame fileURL:(NSURL *)fileURL page:(NSUInteger)page password:(NSString *)phrase
{
	return [self initWithFrame:frame fileURL:fileURL page:page contentPageClass:nil password:phrase];
}

- (id)initWithFrame:(CGRect)frame fileURL:(NSURL *)fileURL page:(NSUInteger)page contentPageClass:(Class)aClass password:(NSString *)phrase
{
	if ((self = [super initWithFrame:frame])) {
		self.scrollsToTop = NO;
		self.delaysContentTouches = NO;
		self.showsVerticalScrollIndicator = NO;
		self.showsHorizontalScrollIndicator = NO;
		self.contentMode = UIViewContentModeRedraw;
		self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		self.backgroundColor = [UIColor clearColor];
		self.userInteractionEnabled = YES;
		self.autoresizesSubviews = NO;
		self.bouncesZoom = YES;
		self.delegate = self;
		
		// create the content page
		aClass = [aClass isSubclassOfClass:[ReaderContentPage class]] ? aClass : [ReaderContentPage class];
		self.contentPage = [[aClass alloc] initWithURL:fileURL page:page password:phrase];
		if (contentPage != nil) {																// Must have a valid and initialized content view
			self.containerView = [[UIView alloc] initWithFrame:contentPage.bounds];
			containerView.autoresizesSubviews = NO;
			containerView.userInteractionEnabled = NO;
			containerView.contentMode = UIViewContentModeRedraw;
			containerView.autoresizingMask = UIViewAutoresizingNone;
			containerView.backgroundColor = [UIColor whiteColor];
			
#if READER_SHOW_SHADOWS
			containerView.layer.shadowOffset = CGSizeMake(0.0f, 0.0f);
			containerView.layer.shadowRadius = 4.0f;
			containerView.layer.shadowOpacity = 1.0f;
			containerView.layer.shadowPath = [UIBezierPath bezierPathWithRect:containerView.bounds].CGPath;
#endif
			
			self.contentSize = contentPage.bounds.size;											// Content size same as view size
			self.contentOffset = CGPointMake((0.0f - CONTENT_INSET), (0.0f - CONTENT_INSET));
			self.contentInset = UIEdgeInsetsMake(CONTENT_INSET, CONTENT_INSET, CONTENT_INSET, CONTENT_INSET);
			
			// add the thumbnail view
			self.thumbView = [[ReaderContentThumb alloc] initWithFrame:contentPage.bounds];
			
			[containerView addSubview:thumbView];
			[containerView addSubview:contentPage];
			[self addSubview:containerView];
			
			[self updateMinimumMaximumZoom];				// Update the minimum and maximum zoom scales
			self.zoomScale = self.minimumZoomScale;			// Set zoom to fit page content
		}
		
		[self addObserver:self forKeyPath:@"frame" options:0 context:NULL];
		self.tag = page;									// Tag the view with the page number
	}
	
	return self;
}

- (void)dealloc
{
	[self removeObserver:self forKeyPath:@"frame"];
}

- (void)showPageThumb:(NSURL *)fileURL page:(NSInteger)page password:(NSString *)phrase guid:(NSString *)guid
{
	BOOL large = ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad); // Page thumb size
	
	CGSize size = (large ? CGSizeMake(PAGE_THUMB_LARGE, PAGE_THUMB_LARGE) : CGSizeMake(PAGE_THUMB_SMALL, PAGE_THUMB_SMALL));
	ReaderThumbRequest *request = [ReaderThumbRequest forView:thumbView fileURL:fileURL password:phrase guid:guid page:page size:size];
	[request process];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if ((object == self) && [keyPath isEqualToString:@"frame"]) {
		CGFloat oldMinimumZoomScale = self.minimumZoomScale;
		[self updateMinimumMaximumZoom];				// Update zoom scale limits
		
		if (self.zoomScale == oldMinimumZoomScale) {	// Old minimum
			self.zoomScale = self.minimumZoomScale;
		}
		else {											// Check against minimum zoom scale
			if (self.zoomScale < self.minimumZoomScale) {
				self.zoomScale = self.minimumZoomScale;
			}
			else {										// Check against maximum zoom scale
				if (self.zoomScale > self.maximumZoomScale) {
					self.zoomScale = self.maximumZoomScale;
				}
			}
		}
	}
}

- (id)singleTap:(UITapGestureRecognizer *)recognizer
{
	return [contentPage singleTap:recognizer];
}

- (BOOL)zoomIncrementAnimated:(BOOL)animated
{
	if (ZOOM_LEVELS > 0) {
		CGFloat zoomScale = self.zoomScale;
		if (zoomScale < self.maximumZoomScale) {
			zoomScale += ((self.maximumZoomScale - self.minimumZoomScale) / ZOOM_LEVELS);
			
			if (zoomScale > self.maximumZoomScale) {
				zoomScale = self.maximumZoomScale;
			}
			
			[self setZoomScale:zoomScale animated:animated];
			return YES;
		}
	}
	return NO;
}

- (BOOL)zoomDecrementAnimated:(BOOL)animated
{
	if (ZOOM_LEVELS > 0) {
		CGFloat zoomScale = self.zoomScale;
		if (zoomScale > self.minimumZoomScale) {
			zoomScale -= ((self.maximumZoomScale - self.minimumZoomScale) / ZOOM_LEVELS);
			
			if (zoomScale < self.minimumZoomScale) {
				zoomScale = self.minimumZoomScale;
			}
			
			[self setZoomScale:zoomScale animated:animated];
			return YES;
		}
	}
	return NO;
}

- (void)zoomResetAnimated:(BOOL)animated
{
	[self setZoomScale:self.minimumZoomScale animated:animated];
}



#pragma mark - UIScrollViewDelegate methods

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView
{
	return containerView;
}

- (void)scrollViewDidEndZooming:(UIScrollView *)scrollView withView:(UIView *)view atScale:(CGFloat)scale
{
	if ([message respondsToSelector:@selector(contentViewDidZoom:)]) {
		[message contentViewDidZoom:self];
	}
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
	if ([message respondsToSelector:@selector(contentViewDidPan:)]) {
		[message contentViewDidPan:self];
	}
}



#pragma mark - UIResponder instance methods

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
	[super touchesBegan:touches withEvent:event];
	[message contentView:self touchesBegan:touches];
}


@end


#pragma mark -

@implementation ReaderContentThumb


- (id)initWithFrame:(CGRect)frame
{
	if ((self = [super initWithFrame:frame])) {
		imageView.contentMode = UIViewContentModeScaleAspectFill;
		imageView.clipsToBounds = YES; // Needed for aspect fill
	}
	
	return self;
}


@end
