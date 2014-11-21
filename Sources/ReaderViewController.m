//
//	ReaderViewController.m
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
#import "ReaderViewController.h"
#import "ReaderThumbCache.h"
#import "ReaderThumbQueue.h"


@interface ReaderViewController ()

@property (nonatomic, readwrite, strong) ReaderDocument *document;
@property (nonatomic, readwrite, strong) NSDate *lastHideTime;
@property (nonatomic, readwrite, assign) ReaderContentView *currentPageView;

@property (weak, nonatomic) UIBarButtonItem *actionItem;

/// The URL to use when sharing the document.
@property (strong, nonatomic) NSURL *shareURL;

/// Need to hold on to our document interaction controller.
@property (strong, nonatomic) UIDocumentInteractionController *documentInteraction;

@end


@implementation ReaderViewController


#define PAGING_VIEWS 3
#define PAGEBAR_HEIGHT 48.0f
#define TAP_AREA_SIZE 48.0f


- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}


+ (UINavigationController *)presentableViewControllerForDocument:(ReaderDocument *)document withDelegate:(id<ReaderViewControllerDelegate>)delegate
{
	ReaderViewController *vc = [[self alloc] initWithReaderDocument:document];
	vc.delegate = delegate;
	return [[UINavigationController alloc] initWithRootViewController:vc];
}


/**
 *  The designated initializer
 */
- (id)initWithReaderDocument:(ReaderDocument *)document
{
	NSParameterAssert([document isKindOfClass:[ReaderDocument class]]);
	if ((self = [super initWithNibName:nil bundle:nil])) {
		NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
		[notificationCenter addObserver:self selector:@selector(applicationWill:) name:UIApplicationWillTerminateNotification object:nil];
		[notificationCenter addObserver:self selector:@selector(applicationWill:) name:UIApplicationWillResignActiveNotification object:nil];
		
		[document updateProperties];
		self.document = document;
		self.title = [document.fileName stringByDeletingPathExtension];
		
		[ReaderThumbCache touchThumbCacheWithGUID:document.guid];				// Touch the document thumb cache directory
		
		// navigation bar items
#if !READER_STANDALONE
		UIBarButtonItem *done = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(didTapDone:)];
		self.navigationItem.rightBarButtonItem = done;
#endif
#if READER_ENABLE_EMAIL || READER_ENABLE_PRINT
		UIBarButtonItem *action = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(didTapAction:)];
		self.navigationItem.leftBarButtonItem = action;
		self.actionItem = action;
#endif
#if READER_BOOKMARKS
		NSAssert(NO, @"Re-implement me!");
		UIImage *markImageN = [UIImage imageNamed:@"Reader-Mark-N.png"];
		UIImage *markImageY = [UIImage imageNamed:@"Reader-Mark-Y.png"];
#endif
	}
	
	return self;
}

- (void)loadView
{
	NSAssert(_document, @"Must have a document");
	self.edgesForExtendedLayout = UIRectEdgeAll;
	self.extendedLayoutIncludesOpaqueBars = NO;
	self.automaticallyAdjustsScrollViewInsets = NO;
	
	[super loadView];
	self.view.backgroundColor = [UIColor whiteColor];
	
	// setup the scroll view
	CGRect viewRect = self.view.bounds;
	self.scrollView = [[UIScrollView alloc] initWithFrame:viewRect];
	_scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	
	_scrollView.scrollsToTop = NO;
	_scrollView.pagingEnabled = YES;
	_scrollView.alwaysBounceVertical = YES;
	_scrollView.showsVerticalScrollIndicator = NO;
	_scrollView.showsHorizontalScrollIndicator = NO;
	_scrollView.contentMode = UIViewContentModeRedraw;
	_scrollView.contentInset = UIEdgeInsetsMake(44.f, 0.f, 0.f, 0.f);
	_scrollView.userInteractionEnabled = YES;
	_scrollView.autoresizesSubviews = NO;
	_scrollView.backgroundColor = [UIColor lightGrayColor];
	_scrollView.delegate = self;
	
	[self.view addSubview:_scrollView];
	
	// add the thumbnail bar at the bottom if we have more than one page
	if ([_document.pageCount integerValue] > 1) {
		CGRect pagebarRect = viewRect;
		pagebarRect.size.height = PAGEBAR_HEIGHT;
		pagebarRect.origin.y = (viewRect.size.height - PAGEBAR_HEIGHT);
		self.mainPagebar = [[ReaderMainPagebar alloc] initWithFrame:pagebarRect document:_document];
		_mainPagebar.delegate = self;
		[self.view addSubview:_mainPagebar];
	}
	
	UITapGestureRecognizer *singleTapOne = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleSingleTap:)];
	singleTapOne.numberOfTouchesRequired = 1; singleTapOne.numberOfTapsRequired = 1; singleTapOne.delegate = self;
	
	UITapGestureRecognizer *doubleTapOne = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleDoubleTap:)];
	doubleTapOne.numberOfTouchesRequired = 1; doubleTapOne.numberOfTapsRequired = 2; doubleTapOne.delegate = self;
	
	UITapGestureRecognizer *doubleTapTwo = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleDoubleTap:)];
	doubleTapTwo.numberOfTouchesRequired = 2; doubleTapTwo.numberOfTapsRequired = 2; doubleTapTwo.delegate = self;
	
	[singleTapOne requireGestureRecognizerToFail:doubleTapOne];
	
	UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
	
	[self.view addGestureRecognizer:singleTapOne];
	[self.view addGestureRecognizer:doubleTapOne];
	[self.view addGestureRecognizer:doubleTapTwo];
	[self.view addGestureRecognizer:longPress];
	
	self.contentViews = [NSMutableDictionary new];
	self.lastHideTime = [NSDate new];
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	
	// Update content views if sizes changed
	if (!CGSizeEqualToSize(lastAppearSize, CGSizeZero)) {
		if (!CGSizeEqualToSize(lastAppearSize, self.view.bounds.size)) {
			[self updateScrollViewContentViews];
		}
		
		lastAppearSize = CGSizeZero; // Reset view size tracking
	}
}

- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];
	
	// First time
	if (CGSizeEqualToSize(_scrollView.contentSize, CGSizeZero)) {
		[self performSelector:@selector(showDocument:) withObject:nil afterDelay:0.02];
	}
	
#if READER_DISABLE_IDLE
	[UIApplication sharedApplication].idleTimerDisabled = YES;
#endif
}

- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
	lastAppearSize = self.view.bounds.size;
	
	// going away?
	if ([self isMovingFromParentViewController] || [self.navigationController ?: self isBeingDismissed]) {
		[_document saveReaderDocument];
		[[ReaderThumbQueue sharedInstance] cancelOperationsWithGUID:_document.guid];
		[[ReaderThumbCache sharedInstance] removeAllObjects];
	}
	
#if READER_DISABLE_IDLE
	[UIApplication sharedApplication].idleTimerDisabled = NO;
#endif
}

- (BOOL)prefersStatusBarHidden
{
	return YES;
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
	return UIStatusBarStyleLightContent;
}


- (NSUInteger)supportedInterfaceOrientations
{
	return UIInterfaceOrientationMaskAll;
}

- (BOOL)shouldAutorotate
{
	return YES;
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
	if (isVisible == NO) {
		return; // iOS present modal bodge
	}
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation duration:(NSTimeInterval)duration
{
	if (isVisible == NO) {
		return; // iOS present modal bodge
	}
	
	[self updateScrollViewContentViews];
	lastAppearSize = CGSizeZero; // Reset view size tracking
}



#pragma mark - UI Support methods

- (void)updateScrollViewContentViews
{
	NSMutableIndexSet *pageSet = [NSMutableIndexSet indexSet];
	[_contentViews enumerateKeysAndObjectsUsingBlock:^(id key, id object, BOOL *stop) {
		ReaderContentView *contentView = object;
		[pageSet addIndex:contentView.tag];
	}];
	
	// reposition pages
	__block CGRect viewRect = CGRectZero;
	viewRect.size = _scrollView.bounds.size;
	__block CGPoint contentOffset = CGPointZero;
	NSUInteger page = [_document.pageNumber unsignedIntegerValue];
	
	[pageSet enumerateIndexesUsingBlock:^(NSUInteger number, BOOL *stop) {
		ReaderContentView *contentView = [_contentViews objectForKey:@(number)];
		contentView.frame = viewRect;
		if (page == number) {
			contentOffset.x = viewRect.origin.x;
		}
		viewRect.origin.x += viewRect.size.width; // Next view frame position
	}];
	
	// update scroll view dimensions
	_scrollView.contentSize = CGSizeMake(viewRect.origin.x, _scrollView.bounds.size.height);
	_scrollView.contentOffset = contentOffset;
}

- (void)updateBookmarkState
{
#if READER_BOOKMARKS
	NSInteger page = [_document.pageNumber integerValue];
	BOOL bookmarked = [_document.bookmarks containsIndex:page];
	UIImage *image = [UIImage imageNamed:(bookmarked ? @"Reader-Mark-Y.png" : @"Reader-Mark-N.png")];
	// TODO: update
#endif
}

- (void)showDocumentPage:(NSUInteger)page
{
	if (page != _currentPage) {
		NSUInteger minValue;
		NSUInteger maxValue;
		NSUInteger maxPage = [_document.pageCount unsignedIntegerValue];
		NSUInteger minPage = 1;
		
		if ((page < minPage) || (page > maxPage)) {
			return;
		}
		
		if (maxPage <= PAGING_VIEWS) {		// Few pages
			minValue = minPage;
			maxValue = maxPage;
		}
		else {								// Handle more pages
			minValue = MAX(minPage, page - 1);
			maxValue = MIN(maxPage, page + 1);
		}
		
		NSMutableIndexSet *newPageSet = [NSMutableIndexSet new];
		NSMutableDictionary *unusedViews = [_contentViews mutableCopy];
		CGRect viewRect = CGRectZero;
		viewRect.size = _scrollView.bounds.size;
		CGPoint contentOffset = _scrollView.contentOffset;
		
		for (NSUInteger number = minValue; number <= maxValue; number++) {
			NSNumber *key = @(number);
			ReaderContentView *contentView = _contentViews[key];
			
			// Create a brand new document content view
			if (contentView == nil) {
				NSURL *fileURL = _document.fileURL;
				NSString *phrase = _document.password;
				contentView = [[ReaderContentView alloc] initWithFrame:viewRect fileURL:fileURL page:number contentPageClass:[self classForViewPages] password:phrase];
				[self didAddContentView:contentView forPage:number];
				[_scrollView addSubview:contentView];
				[_contentViews setObject:contentView forKey:key];
				contentView.message = self;
				[newPageSet addIndex:number];
			}
			
			// Reposition the existing content view
			else {
				contentView.frame = viewRect;
				[contentView zoomResetAnimated:NO];
				[unusedViews removeObjectForKey:key];
			}
			
			// make correct page visible
			if (page == number) {
				contentOffset.x = viewRect.origin.x;
			}
			
			viewRect.origin.x += viewRect.size.width;
		}
		
		// remove unused views
		[unusedViews enumerateKeysAndObjectsUsingBlock:^(id key, id object, BOOL *stop) {
			[object removeFromSuperview];
			[_contentViews removeObjectForKey:key];
		}];
		
		// update scroll offset and page number
		_scrollView.contentSize = CGSizeMake(viewRect.origin.x, _scrollView.bounds.size.height);
		_scrollView.contentOffset = contentOffset;
		_document.pageNumber = @(page);
		
		NSURL *fileURL = _document.fileURL;
		NSString *phrase = _document.password;
		NSString *guid = _document.guid;
		
		// Preview visible page first
		if ([newPageSet containsIndex:page]) {
			self.currentPageView = _contentViews[@(page)];
			[_currentPageView showPageThumb:fileURL page:page password:phrase guid:guid];
			[newPageSet removeIndex:page];
		}
		
		// Show previews for other pages
		[newPageSet enumerateIndexesWithOptions:NSEnumerationReverse usingBlock:^(NSUInteger number, BOOL *stop) {
			ReaderContentView *targetView = _contentViews[@(number)];
			[targetView showPageThumb:fileURL page:number password:phrase guid:guid];
		}];
		
		// update and track current page
		[_mainPagebar updatePagebar];
		[self updateBookmarkState];
		_currentPage = page;
	}
}

- (void)showDocument:(id)object
{
	[self showDocumentPage:[_document.pageNumber integerValue]];
	_document.lastOpen = [NSDate date];
	isVisible = YES;
}

/**
 *	Called when we add a new view for our document. The default implementation does nothing.
 */
- (void)didAddContentView:(ReaderContentView *)aContentView forPage:(NSUInteger)pageNumber
{
}


#pragma mark - Document Handling

- (NSData *)redrawnDocumentDataFor:(ReaderContentTargetType)dataType
{
	NSArray *pages = [_contentViews allValues];
	if ([pages count] > 0) {
		NSMutableData* pdfData = [NSMutableData data];
		
		// create the PDF context using the media box of the first page
		ReaderContentView *firstPage = [pages objectAtIndex:0];
		CGRect mediaBox = firstPage.contentPage.bounds;
		UIGraphicsBeginPDFContextToData(pdfData, mediaBox, nil);
		CGContextRef pdf = UIGraphicsGetCurrentContext();
		
		// render all pages
		NSUInteger numPages = [[_document pageCount] unsignedIntegerValue];
		for (NSUInteger number = 1; number <= numPages; number++) {
			NSNumber *key = [NSNumber numberWithInteger:number];
			ReaderContentPage *contentPage = [[_contentViews objectForKey:key] contentPage];
			if (contentPage) {
				contentPage.currentRenderTarget = dataType;
				UIGraphicsBeginPDFPageWithInfo(contentPage.bounds, nil);
				[contentPage.layer renderInContext:pdf];
			}
		}
		
		// return data
		UIGraphicsEndPDFContext();
		return pdfData;
	}
	NSLog(@"There are no pages in our document");
	return nil;
}

/**
 *	We can return a subclass of ReaderContentPage if we want
 */
- (Class)classForViewPages
{
	return nil;				// if we return nil, the default class (ReaderContentPage) will be used by ReaderContentView
}



#pragma mark - Toolbar Handling

- (BOOL)toolbarsHidden
{
	if (self.navigationController && self.navigationController.navigationBarHidden) {
		return YES;
	}
	return _mainPagebar.hidden;
}

- (void)showToolbarsAnimated:(BOOL)animated
{
	[self.navigationController setNavigationBarHidden:NO animated:animated];
	[_mainPagebar showPagebar];
}

- (void)hideToolbarsAnimated:(BOOL)animated
{
	[self.navigationController setNavigationBarHidden:YES animated:animated];
	[_mainPagebar hidePagebar];
	self.lastHideTime = [NSDate new];
}



#pragma mark - UIScrollViewDelegate methods

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
	CGFloat contentOffsetX = scrollView.contentOffset.x;
	
	__block NSInteger page = 0;
	[_contentViews enumerateKeysAndObjectsUsingBlock:^(id key, id object, BOOL *stop) {
		ReaderContentView *contentView = object;
		if (contentView.frame.origin.x == contentOffsetX) {
			page = contentView.tag;
			*stop = YES;
		}
	}];
	
	if (page != 0) {
		[self showDocumentPage:page];
	}
}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView
{
	[self showDocumentPage:_scrollView.tag];
	_scrollView.tag = 0; // Clear page number tag
}



#pragma mark - UIGestureRecognizerDelegate methods

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)recognizer shouldReceiveTouch:(UITouch *)touch
{
	return [touch.view isKindOfClass:[UIScrollView class]];
}



#pragma mark UIGestureRecognizer action methods

- (void)decrementPageNumber
{
	// Scroll view did end
	if (_scrollView.tag == 0) {
		NSInteger page = [_document.pageNumber integerValue];
		NSInteger maxPage = [_document.pageCount integerValue];
		NSInteger minPage = 1; // Minimum

		if ((maxPage > minPage) && (page != minPage)) {
			CGPoint contentOffset = _scrollView.contentOffset;
			contentOffset.x -= _scrollView.bounds.size.width;
			[_scrollView setContentOffset:contentOffset animated:YES];
			_scrollView.tag = (page - 1); // Decrement page number
		}
	}
}

- (void)incrementPageNumber
{
	// Scroll view did end
	if (_scrollView.tag == 0) {
		NSInteger page = [_document.pageNumber integerValue];
		NSInteger maxPage = [_document.pageCount integerValue];
		NSInteger minPage = 1; // Minimum

		if ((maxPage > minPage) && (page != maxPage)) {
			CGPoint contentOffset = _scrollView.contentOffset;
			contentOffset.x += _scrollView.bounds.size.width;
			[_scrollView setContentOffset:contentOffset animated:YES];
			_scrollView.tag = (page + 1); // Increment page number
		}
	}
}

- (void)handleSingleTap:(UITapGestureRecognizer *)recognizer
{
	if (recognizer.state == UIGestureRecognizerStateRecognized) {
		CGRect viewRect = recognizer.view.bounds;
		CGPoint point = [recognizer locationInView:recognizer.view];
		CGRect areaRect = CGRectInset(viewRect, TAP_AREA_SIZE, 0.0f);
		if (CGRectContainsPoint(areaRect, point)) {
			NSInteger page = [_document.pageNumber integerValue];	// Current page #
			NSNumber *key = [NSNumber numberWithInteger:page];		// Page number key
			ReaderContentView *targetView = [_contentViews objectForKey:key];
			
			// Handle the returned target object
			id target = [targetView singleTap:recognizer];
			if (target != nil) {
				
				// Open a URL
				if ([target isKindOfClass:[NSURL class]]) {
					NSURL *url = (NSURL *)target;
					
					// Handle a missing URL scheme
					if (url.scheme == nil) {
						NSString *www = url.absoluteString;
						
						// Check for 'www' prefix
						if ([www hasPrefix:@"www"]) {
							NSString *http = [NSString stringWithFormat:@"http://%@", www];
							url = [NSURL URLWithString:http];
						}
					}

					if (![[UIApplication sharedApplication] openURL:url]) {
						NSLog(@"%s '%@'", __FUNCTION__, url);		// Bad or unknown URL
					}
				}
				
				// Not a URL, so check for other possible object type
				else {
					if ([target isKindOfClass:[NSNumber class]]) {			// Goto page
						NSInteger value = [target integerValue];
						[self showDocumentPage:value];						// Show the page
					}
				}
			}
			
			// Nothing active tapped in the target content view
			else {
				if ([_lastHideTime timeIntervalSinceNow] < -0.75) {			// Delay since hide
					if ([self toolbarsHidden]) {
						[self showToolbarsAnimated:YES];
					}
				}
			}
			
			return;
		}
		
		CGRect nextPageRect = viewRect;
		nextPageRect.size.width = TAP_AREA_SIZE;
		nextPageRect.origin.x = (viewRect.size.width - TAP_AREA_SIZE);
		
		if (CGRectContainsPoint(nextPageRect, point)) {						// page++ area
			[self incrementPageNumber];
			return;
		}
		
		CGRect prevPageRect = viewRect;
		prevPageRect.size.width = TAP_AREA_SIZE;
		
		if (CGRectContainsPoint(prevPageRect, point)) {						// page-- area
			[self decrementPageNumber];
			return;
		}
	}
}

- (void)handleDoubleTap:(UITapGestureRecognizer *)recognizer
{
	if (recognizer.state == UIGestureRecognizerStateRecognized) {
		CGRect viewRect = recognizer.view.bounds;
		CGPoint point = [recognizer locationInView:recognizer.view];
		CGRect zoomArea = CGRectInset(viewRect, TAP_AREA_SIZE, TAP_AREA_SIZE);
		
		if (CGRectContainsPoint(zoomArea, point)) {							// Double tap is in the zoom area
			NSInteger page = [_document.pageNumber integerValue];
			NSNumber *key = [NSNumber numberWithInteger:page];				// Page number key
			ReaderContentView *targetView = [_contentViews objectForKey:key];
			
			// double tap toggles between zooming in and zooming out
			if (targetView.zoomScale > targetView.minimumZoomScale) {
				[targetView zoomResetAnimated:YES];
			}
			else {
				[targetView zoomIncrementAnimated:YES];
			}
			return;
		}

		CGRect nextPageRect = viewRect;
		nextPageRect.size.width = TAP_AREA_SIZE;
		nextPageRect.origin.x = (viewRect.size.width - TAP_AREA_SIZE);
		
		// page++ area
		if (CGRectContainsPoint(nextPageRect, point)) {
			[self incrementPageNumber];
			return;
		}
		
		CGRect prevPageRect = viewRect;
		prevPageRect.size.width = TAP_AREA_SIZE;
		
		// page-- area
		if (CGRectContainsPoint(prevPageRect, point)) {
			[self decrementPageNumber];
			return;
		}
	}
}

- (void)handleLongPress:(UILongPressGestureRecognizer *)recognizer
{
}



#pragma mark - ReaderContentViewDelegate methods

- (void)contentView:(ReaderContentView *)contentView touchesBegan:(NSSet *)touches
{
	if (![self toolbarsHidden]) {
		
		// Single touches only
		if (touches.count == 1) {
			UITouch *touch = [touches anyObject];
			CGPoint point = [touch locationInView:self.view];
			CGRect areaRect = CGRectInset(self.view.bounds, TAP_AREA_SIZE, TAP_AREA_SIZE);
			if (CGRectContainsPoint(areaRect, point) == false) {
				return;
			}
		}
		
		[self hideToolbarsAnimated:YES];
	}
}



#pragma mark - Navigation Bar Methods

- (void)didTapDone:(id)sender
{
#if !READER_STANDALONE
	[_delegate dismissReaderViewController:self];
#endif
}

- (void)didTapAction:(id)sender
{
	self.shareURL = [self preparedForSharing];
	if (!_shareURL) {
		NSLog(@"Did not get a prepared action URL, cannot share");
		return;
	}
	
	// create and show document interaction controller
	// There is a bug in iOS 8 and 8.1 that makes iOS log the full PDF data to console:
	// http://openradar.appspot.com/radar?id=5800473659441152
	// Workaround would be to use UIActivityController, but that one doesn't show apps capable of opening PDF, so we
	// have to use UIDocumentInteractionController.
	self.documentInteraction = [UIDocumentInteractionController interactionControllerWithURL:_shareURL];
	_documentInteraction.delegate = self;
	_documentInteraction.name = self.title;
	
	[_documentInteraction presentOptionsMenuFromBarButtonItem:_actionItem animated:YES];
}

- (void)documentInteractionControllerDidDismissOptionsMenu:(UIDocumentInteractionController *)controller
{
	if (controller == _documentInteraction) {
		self.documentInteraction = nil;
	}
}

- (NSURL *)preparedForSharing
{
	return _document.fileURL;
}


// TODO: re-implement
- (void)presentThumbsFromButton:(UIButton *)button
{
	ThumbsViewController *thumbsViewController = [[ThumbsViewController alloc] initWithReaderDocument:_document];
	thumbsViewController.delegate = self;
	thumbsViewController.title = self.title;
	thumbsViewController.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
	thumbsViewController.modalPresentationStyle = UIModalPresentationFullScreen;
	
	[self presentViewController:thumbsViewController animated:NO completion:NULL];
}

// TODO: re-implement
- (void)setBookmarkFromButton:(UIButton *)button
{
	NSInteger page = [_document.pageNumber integerValue];
	
	// add or remove the bookmarked page index
	if ([_document.bookmarks containsIndex:page]) {
		[_document.bookmarks removeIndex:page];
	}
	else {
		[_document.bookmarks addIndex:page];
	}
	
	[self updateBookmarkState];
}



#pragma mark - ThumbsViewControllerDelegate methods

- (void)dismissThumbsViewController:(ThumbsViewController *)viewController
{
	[self updateBookmarkState];
	[self dismissViewControllerAnimated:YES completion:NULL];
	//[self dismissModalViewControllerAnimated:NO];
}

- (void)thumbsViewController:(ThumbsViewController *)viewController gotoPage:(NSInteger)page
{
	[self showDocumentPage:page];
}



#pragma mark - ReaderMainPagebarDelegate methods

- (void)pagebar:(ReaderMainPagebar *)pagebar gotoPage:(NSInteger)page
{
	[self showDocumentPage:page];
}



#pragma mark - UIApplication notification methods

- (void)applicationWill:(NSNotification *)notification
{
	// Save any ReaderDocument object changes
	[_document saveReaderDocument];
}


@end
