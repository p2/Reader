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

@end


@implementation ReaderViewController

#pragma mark Constants

#define PAGING_VIEWS 3

#define TOOLBAR_HEIGHT 44.0f
#define PAGEBAR_HEIGHT 48.0f

#define TAP_AREA_SIZE 48.0f

#pragma mark Properties

@synthesize delegate, document;
@synthesize theScrollView, mainToolbar, mainPagebar, contentViews;
@synthesize lastHideTime;


#pragma mark - UI Support methods

- (void)updateScrollViewContentSize
{
	DXLog(@"");
	
	NSInteger count = [document.pageCount integerValue];
	if (count > PAGING_VIEWS) {
		count = PAGING_VIEWS; // Limit
	}

	CGFloat contentHeight = theScrollView.bounds.size.height;
	CGFloat contentWidth = (theScrollView.bounds.size.width * count);
	theScrollView.contentSize = CGSizeMake(contentWidth, contentHeight);
}

- (void)updateScrollViewContentViews
{
	DXLog(@"");
	
	[self updateScrollViewContentSize]; // Update the content size
	NSMutableIndexSet *pageSet = [NSMutableIndexSet indexSet]; // Page set
	
	[contentViews enumerateKeysAndObjectsUsingBlock: // Enumerate content views
		^(id key, id object, BOOL *stop)
		{
			ReaderContentView *contentView = object;
			[pageSet addIndex:contentView.tag];
		}
	];

	__block CGRect viewRect = CGRectZero; viewRect.size = theScrollView.bounds.size;
	__block CGPoint contentOffset = CGPointZero; NSInteger page = [document.pageNumber integerValue];

	[pageSet enumerateIndexesUsingBlock: // Enumerate page number set
		^(NSUInteger number, BOOL *stop)
		{
			NSNumber *key = [NSNumber numberWithInteger:number]; // # key
			ReaderContentView *contentView = [contentViews objectForKey:key];
			contentView.frame = viewRect; if (page == number) contentOffset = viewRect.origin;
			viewRect.origin.x += viewRect.size.width; // Next view frame position
		}
	];

	if (CGPointEqualToPoint(theScrollView.contentOffset, contentOffset) == false)
	{
		theScrollView.contentOffset = contentOffset; // Update content offset
	}
}

- (void)updateToolbarBookmarkIcon
{
	DXLog(@"");
	
	NSInteger page = [document.pageNumber integerValue];
	BOOL bookmarked = [document.bookmarks containsIndex:page];
	[mainToolbar setBookmarkState:bookmarked]; // Update
}

- (void)showDocumentPage:(NSInteger)page
{
	DXLog(@"");
	
	if (page != currentPage) // Only if different
	{
		NSInteger minValue; NSInteger maxValue;
		NSInteger maxPage = [document.pageCount integerValue];
		NSInteger minPage = 1;

		if ((page < minPage) || (page > maxPage)) return;

		if (maxPage <= PAGING_VIEWS) // Few pages
		{
			minValue = minPage;
			maxValue = maxPage;
		}
		else // Handle more pages
		{
			minValue = (page - 1);
			maxValue = (page + 1);

			if (minValue < minPage)
				{minValue++; maxValue++;}
			else
				if (maxValue > maxPage)
					{minValue--; maxValue--;}
		}

		NSMutableIndexSet *newPageSet = [NSMutableIndexSet new];
		NSMutableDictionary *unusedViews = [contentViews mutableCopy];
		CGRect viewRect = CGRectZero;
		viewRect.size = theScrollView.bounds.size;
		
		for (NSInteger number = minValue; number <= maxValue; number++) {
			NSNumber *key = [NSNumber numberWithInteger:number]; // # key
			ReaderContentView *contentView = [contentViews objectForKey:key];
			if (contentView == nil) // Create a brand new document content view
			{
				NSURL *fileURL = document.fileURL;
				NSString *phrase = document.password;
				contentView = [[ReaderContentView alloc] initWithFrame:viewRect fileURL:fileURL page:number contentPageClass:[self classForViewPages] password:phrase];
				[self didAddContentView:contentView forPage:number];
				[theScrollView addSubview:contentView];
				[contentViews setObject:contentView forKey:key];
				contentView.message = self;
				[newPageSet addIndex:number];
			}
			else // Reposition the existing content view
			{
				contentView.frame = viewRect; [contentView zoomReset];
				[unusedViews removeObjectForKey:key];
			}
			
			viewRect.origin.x += viewRect.size.width;
		}

		[unusedViews enumerateKeysAndObjectsUsingBlock: // Remove unused views
			^(id key, id object, BOOL *stop) {
				[contentViews removeObjectForKey:key];
				ReaderContentView *contentView = object;
				[contentView removeFromSuperview];
			}
		];
		
		unusedViews = nil; // Release unused views
		
		CGFloat viewWidthX1 = viewRect.size.width;
		CGFloat viewWidthX2 = (viewWidthX1 * 2.0f);
		CGPoint contentOffset = CGPointZero;

		if (maxPage >= PAGING_VIEWS)
		{
			if (page == maxPage)
				contentOffset.x = viewWidthX2;
			else
				if (page != minPage)
					contentOffset.x = viewWidthX1;
		}
		else
			if (page == (PAGING_VIEWS - 1))
				contentOffset.x = viewWidthX1;

		if (CGPointEqualToPoint(theScrollView.contentOffset, contentOffset) == false)
		{
			theScrollView.contentOffset = contentOffset; // Update content offset
		}

		if ([document.pageNumber integerValue] != page) // Only if different
		{
			document.pageNumber = [NSNumber numberWithInteger:page]; // Update page number
		}

		NSURL *fileURL = document.fileURL; NSString *phrase = document.password; NSString *guid = document.guid;

		if ([newPageSet containsIndex:page] == YES) // Preview visible page first
		{
			NSNumber *key = [NSNumber numberWithInteger:page]; // # key
			ReaderContentView *targetView = [contentViews objectForKey:key];
			[targetView showPageThumb:fileURL page:page password:phrase guid:guid];
			[newPageSet removeIndex:page]; // Remove visible page from set
		}

		[newPageSet enumerateIndexesWithOptions:NSEnumerationReverse usingBlock: // Show previews
			^(NSUInteger number, BOOL *stop)
			{
				NSNumber *key = [NSNumber numberWithInteger:number]; // # key
				ReaderContentView *targetView = [contentViews objectForKey:key];
				[targetView showPageThumb:fileURL page:number password:phrase guid:guid];
			}
		];

		newPageSet = nil; // Release new page set
		[mainPagebar updatePagebar]; // Update the pagebar display
		[self updateToolbarBookmarkIcon]; // Update bookmark
		currentPage = page; // Track current page number
	}
}

- (void)showDocument:(id)object
{
	DXLog(@"");
	
	[self updateScrollViewContentSize]; // Set content size
	[self showDocumentPage:[document.pageNumber integerValue]]; // Show
	document.lastOpen = [NSDate date]; // Update last opened date
	isVisible = YES; // iOS present modal bodge
}

/**
 *	Called when we add a new view for our document. The default implementation does nothing.
 */
- (void)didAddContentView:(ReaderContentView *)aContentView forPage:(NSInteger)pageNumber
{
}


#pragma mark - Document Handling
/**
 *	@returns An NSData representation of the document, depending on READER_REDRAW_FOR_EXPORT either just read from file or re-rendered into a PDF context
 */
- (NSData *)documentData
{
# if READER_REDRAW_FOR_EXPORT
	NSArray *pages = [contentViews allValues];
	if ([pages count] > 0) {
		NSMutableData* pdfData = [NSMutableData data];
		
		// create the PDF context using the media box of the first page
		ReaderContentView *firstPage = [pages objectAtIndex:0];
		CGRect mediaBox = firstPage.contentPage.bounds;
		UIGraphicsBeginPDFContextToData(pdfData, mediaBox, nil);
		CGContextRef pdf = UIGraphicsGetCurrentContext();
		
		// render all pages
		NSUInteger numPages = [[document pageCount] unsignedIntegerValue];
		for (NSUInteger number = 1; number <= numPages; number++) {
			NSNumber *key = [NSNumber numberWithInteger:number];
			ReaderContentPage *contentPage = [[contentViews objectForKey:key] contentPage];
			if (contentPage) {
				UIGraphicsBeginPDFPageWithInfo(contentPage.bounds, nil);
				[contentPage.layer renderInContext:pdf];
			}
		}
		
		// return data
		UIGraphicsEndPDFContext();
		return pdfData;
	}
	DXLog(@"There are no pages in our document");
	return nil;
# else
	return [NSData dataWithContentsOfURL:document.fileURL options:(NSDataReadingMapped|NSDataReadingUncached) error:nil];
# endif
}


/**
 *	We can return a subclass of ReaderContentPage if we want
 */
- (Class)classForViewPages
{
	return nil;				// if we return nil, the default class (ReaderContentPage) will be used by ReaderContentView
}



#pragma mark - UIViewController methods

- (id)initWithReaderDocument:(ReaderDocument *)object
{
	DXLog(@"");
	id reader = nil; // ReaderViewController object

	if ((object != nil) && ([object isKindOfClass:[ReaderDocument class]]))
	{
		if ((self = [super initWithNibName:nil bundle:nil])) // Designated initializer
		{
			NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
			[notificationCenter addObserver:self selector:@selector(applicationWill:) name:UIApplicationWillTerminateNotification object:nil];
			[notificationCenter addObserver:self selector:@selector(applicationWill:) name:UIApplicationWillResignActiveNotification object:nil];
			
			[object updateProperties];
			self.document = object;
			[ReaderThumbCache touchThumbCacheWithGUID:object.guid]; // Touch the document thumb cache directory
			reader = self; // Return an initialized ReaderViewController object
		}
	}

	return reader;
}

/*
- (void)loadView
{
	DXLog(@"");

	// Implement loadView to create a view hierarchy programmatically, without using a nib.
}
*/

- (void)viewDidLoad
{
	DXLog(@"%@", NSStringFromCGRect(self.view.bounds));
	[super viewDidLoad];

	NSAssert(!(document == nil), @"ReaderDocument == nil");

	assert(self.splitViewController == nil); // Not supported (sorry)

	self.view.backgroundColor = [UIColor scrollViewTexturedBackgroundColor];
	
	// setup the scroll view
	CGRect viewRect = self.view.bounds;
	self.theScrollView = [[UIScrollView alloc] initWithFrame:viewRect];
	
	theScrollView.scrollsToTop = NO;
	theScrollView.pagingEnabled = YES;
	theScrollView.delaysContentTouches = NO;
	theScrollView.showsVerticalScrollIndicator = NO;
	theScrollView.showsHorizontalScrollIndicator = NO;
	theScrollView.contentMode = UIViewContentModeRedraw;
	theScrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	theScrollView.backgroundColor = [UIColor clearColor];
	theScrollView.userInteractionEnabled = YES;
	theScrollView.autoresizesSubviews = NO;
	theScrollView.delegate = self;

	[self.view addSubview:theScrollView];
	
	// setup the toolbal at top
	CGRect toolbarRect = viewRect;
	toolbarRect.size.height = TOOLBAR_HEIGHT;
	
	self.mainToolbar = [[ReaderMainToolbar alloc] initWithFrame:toolbarRect document:document];
	mainToolbar.delegate = self;
	[self.view addSubview:mainToolbar];
	
	// add the thumbnail bar at the bottom if we have more than one page
	if ([document.pageCount integerValue] > 1) {
		CGRect pagebarRect = viewRect;
		pagebarRect.size.height = PAGEBAR_HEIGHT;
		pagebarRect.origin.y = (viewRect.size.height - PAGEBAR_HEIGHT);
		self.mainPagebar = [[ReaderMainPagebar alloc] initWithFrame:pagebarRect document:document];
		mainPagebar.delegate = self;
		[self.view addSubview:mainPagebar];
	}
	
	UITapGestureRecognizer *singleTapOne = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleSingleTap:)];
	singleTapOne.numberOfTouchesRequired = 1; singleTapOne.numberOfTapsRequired = 1; singleTapOne.delegate = self;
	
	UITapGestureRecognizer *doubleTapOne = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleDoubleTap:)];
	doubleTapOne.numberOfTouchesRequired = 1; doubleTapOne.numberOfTapsRequired = 2; doubleTapOne.delegate = self;
	
	UITapGestureRecognizer *doubleTapTwo = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleDoubleTap:)];
	doubleTapTwo.numberOfTouchesRequired = 2; doubleTapTwo.numberOfTapsRequired = 2; doubleTapTwo.delegate = self;
	
	[singleTapOne requireGestureRecognizerToFail:doubleTapOne]; // Single tap requires double tap to fail
	
	[self.view addGestureRecognizer:singleTapOne]; 
	[self.view addGestureRecognizer:doubleTapOne]; 
	[self.view addGestureRecognizer:doubleTapTwo]; 
	
	self.contentViews = [NSMutableDictionary new];
	self.lastHideTime = [NSDate new];
}

- (void)viewWillAppear:(BOOL)animated
{
	DXLog(@"%@", NSStringFromCGRect(self.view.bounds));
	[super viewWillAppear:animated];

	if (CGSizeEqualToSize(lastAppearSize, CGSizeZero) == false)
	{
		if (CGSizeEqualToSize(lastAppearSize, self.view.bounds.size) == false)
		{
			[self updateScrollViewContentViews]; // Update content views
		}

		lastAppearSize = CGSizeZero; // Reset view size tracking
	}
}

- (void)viewDidAppear:(BOOL)animated
{
	DXLog(@"%@", NSStringFromCGRect(self.view.bounds));
	[super viewDidAppear:animated];
	
	if (CGSizeEqualToSize(theScrollView.contentSize, CGSizeZero)) // First time
	{
		[self performSelector:@selector(showDocument:) withObject:nil afterDelay:0.02];
	}

#if READER_DISABLE_IDLE
	[UIApplication sharedApplication].idleTimerDisabled = YES;
#endif
}

- (void)viewWillDisappear:(BOOL)animated
{
	DXLog(@"%@", NSStringFromCGRect(self.view.bounds));
	[super viewWillDisappear:animated];
	lastAppearSize = self.view.bounds.size; // Track view size
	
#if READER_DISABLE_IDLE
	[UIApplication sharedApplication].idleTimerDisabled = NO;
#endif
}

- (void)viewDidDisappear:(BOOL)animated
{
	DXLog(@"%@", NSStringFromCGRect(self.view.bounds));
	
	[super viewDidDisappear:animated];
}

- (void)viewDidUnload
{
	DXLog(@"");
	self.mainToolbar = nil;
	self.mainPagebar = nil;
	self.theScrollView = nil;
	self.contentViews = nil;
	self.lastHideTime = nil;
	
	lastAppearSize = CGSizeZero;
	currentPage = 0;
	
	[super viewDidUnload];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	DXLog(@"%d", interfaceOrientation);
	return YES;
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
	DXLog(@"%@ (%d)", NSStringFromCGRect(self.view.bounds), toInterfaceOrientation);
	
	if (isVisible == NO) return; // iOS present modal bodge

	if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
	{
		if (printInteraction != nil) [printInteraction dismissAnimated:NO];
	}
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation duration:(NSTimeInterval)duration
{
	DXLog(@"%@ (%d)", NSStringFromCGRect(self.view.bounds), interfaceOrientation);
	
	if (isVisible == NO) return; // iOS present modal bodge

	[self updateScrollViewContentViews]; // Update content views
	lastAppearSize = CGSizeZero; // Reset view size tracking
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
	DXLog(@"%@ (%d to %d)", NSStringFromCGRect(self.view.bounds), fromInterfaceOrientation, [self interfaceOrientation]);
	//if (isVisible == NO) return; // iOS present modal bodge
	//if (fromInterfaceOrientation == self.interfaceOrientation) return;
}

- (void)didReceiveMemoryWarning
{
	DXLog(@"");
	[super didReceiveMemoryWarning];
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - UIScrollViewDelegate methods

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
	DXLog(@"");
	__block NSInteger page = 0;

	CGFloat contentOffsetX = scrollView.contentOffset.x;

	[contentViews enumerateKeysAndObjectsUsingBlock: // Enumerate content views
		^(id key, id object, BOOL *stop)
		{
			ReaderContentView *contentView = object;
			if (contentView.frame.origin.x == contentOffsetX)
			{
				page = contentView.tag;
				*stop = YES;
			}
		}
	];

	if (page != 0) [self showDocumentPage:page]; // Show the page
}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView
{
	DXLog(@"");

	[self showDocumentPage:theScrollView.tag]; // Show page

	theScrollView.tag = 0; // Clear page number tag
}

#pragma mark - UIGestureRecognizerDelegate methods

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)recognizer shouldReceiveTouch:(UITouch *)touch
{
	DXLog(@"");

	if ([touch.view isKindOfClass:[UIScrollView class]]) return YES;

	return NO;
}

#pragma mark UIGestureRecognizer action methods

- (void)decrementPageNumber
{
	DXLog(@"");

	if (theScrollView.tag == 0) // Scroll view did end
	{
		NSInteger page = [document.pageNumber integerValue];
		NSInteger maxPage = [document.pageCount integerValue];
		NSInteger minPage = 1; // Minimum

		if ((maxPage > minPage) && (page != minPage))
		{
			CGPoint contentOffset = theScrollView.contentOffset;
			contentOffset.x -= theScrollView.bounds.size.width; // -= 1
			[theScrollView setContentOffset:contentOffset animated:YES];
			theScrollView.tag = (page - 1); // Decrement page number
		}
	}
}

- (void)incrementPageNumber
{
	DXLog(@"");

	if (theScrollView.tag == 0) // Scroll view did end
	{
		NSInteger page = [document.pageNumber integerValue];
		NSInteger maxPage = [document.pageCount integerValue];
		NSInteger minPage = 1; // Minimum

		if ((maxPage > minPage) && (page != maxPage))
		{
			CGPoint contentOffset = theScrollView.contentOffset;
			contentOffset.x += theScrollView.bounds.size.width; // += 1
			[theScrollView setContentOffset:contentOffset animated:YES];
			theScrollView.tag = (page + 1); // Increment page number
		}
	}
}

- (void)handleSingleTap:(UITapGestureRecognizer *)recognizer
{
	DXLog(@"");

	if (recognizer.state == UIGestureRecognizerStateRecognized)
	{
		CGRect viewRect = recognizer.view.bounds; // View bounds
		CGPoint point = [recognizer locationInView:recognizer.view];
		CGRect areaRect = CGRectInset(viewRect, TAP_AREA_SIZE, 0.0f); // Area
		if (CGRectContainsPoint(areaRect, point)) // Single tap is inside the area
		{
			NSInteger page = [document.pageNumber integerValue]; // Current page #
			NSNumber *key = [NSNumber numberWithInteger:page]; // Page number key
			ReaderContentView *targetView = [contentViews objectForKey:key];

			id target = [targetView singleTap:recognizer]; // Process tap
			if (target != nil) // Handle the returned target object
			{
				if ([target isKindOfClass:[NSURL class]]) // Open a URL
				{
					NSURL *url = (NSURL *)target; // Cast to a NSURL object
					if (url.scheme == nil) // Handle a missing URL scheme
					{
						NSString *www = url.absoluteString; // Get URL string
						if ([www hasPrefix:@"www"] == YES) // Check for 'www' prefix
						{
							NSString *http = [NSString stringWithFormat:@"http://%@", www];
							url = [NSURL URLWithString:http]; // Proper http-based URL
						}
					}

					if ([[UIApplication sharedApplication] openURL:url] == NO)
					{
						#ifdef DEBUG
							NSLog(@"%s '%@'", __FUNCTION__, url); // Bad or unknown URL
						#endif
					}
				}
				else // Not a URL, so check for other possible object type
				{
					if ([target isKindOfClass:[NSNumber class]]) // Goto page
					{
						NSInteger value = [target integerValue]; // Number
						[self showDocumentPage:value]; // Show the page
					}
				}
			}
			else // Nothing active tapped in the target content view
			{
				if ([lastHideTime timeIntervalSinceNow] < -0.75) // Delay since hide
				{
					if ((mainToolbar.hidden == YES) || (mainPagebar.hidden == YES))
					{
						[mainToolbar showToolbar]; [mainPagebar showPagebar]; // Show
					}
				}
			}

			return;
		}

		CGRect nextPageRect = viewRect;
		nextPageRect.size.width = TAP_AREA_SIZE;
		nextPageRect.origin.x = (viewRect.size.width - TAP_AREA_SIZE);
		
		if (CGRectContainsPoint(nextPageRect, point)) // page++ area
		{
			[self incrementPageNumber]; return;
		}
		
		CGRect prevPageRect = viewRect;
		prevPageRect.size.width = TAP_AREA_SIZE;
		
		if (CGRectContainsPoint(prevPageRect, point)) // page-- area
		{
			[self decrementPageNumber]; return;
		}
	}
}

- (void)handleDoubleTap:(UITapGestureRecognizer *)recognizer
{
	DXLog(@"");

	if (recognizer.state == UIGestureRecognizerStateRecognized)
	{
		CGRect viewRect = recognizer.view.bounds; // View bounds
		CGPoint point = [recognizer locationInView:recognizer.view];
		CGRect zoomArea = CGRectInset(viewRect, TAP_AREA_SIZE, TAP_AREA_SIZE);
		
		if (CGRectContainsPoint(zoomArea, point)) // Double tap is in the zoom area
		{
			NSInteger page = [document.pageNumber integerValue]; // Current page #
			NSNumber *key = [NSNumber numberWithInteger:page]; // Page number key
			ReaderContentView *targetView = [contentViews objectForKey:key];
			
			switch (recognizer.numberOfTouchesRequired) // Touches count
			{
				case 1: // One finger double tap: zoom ++
				{
					[targetView zoomIncrement]; break;
				}

				case 2: // Two finger double tap: zoom --
				{
					[targetView zoomDecrement]; break;
				}
			}
			
			return;
		}

		CGRect nextPageRect = viewRect;
		nextPageRect.size.width = TAP_AREA_SIZE;
		nextPageRect.origin.x = (viewRect.size.width - TAP_AREA_SIZE);
		
		if (CGRectContainsPoint(nextPageRect, point)) // page++ area
		{
			[self incrementPageNumber]; return;
		}
		
		CGRect prevPageRect = viewRect;
		prevPageRect.size.width = TAP_AREA_SIZE;
		
		if (CGRectContainsPoint(prevPageRect, point)) // page-- area
		{
			[self decrementPageNumber];
			return;
		}
	}
}

#pragma mark - ReaderContentViewDelegate methods

- (void)contentView:(ReaderContentView *)contentView touchesBegan:(NSSet *)touches
{
	DXLog(@"");
	
	if ((mainToolbar.hidden == NO) || (mainPagebar.hidden == NO))
	{
		if (touches.count == 1) // Single touches only
		{
			UITouch *touch = [touches anyObject]; // Touch info
			CGPoint point = [touch locationInView:self.view]; // Touch location
			CGRect areaRect = CGRectInset(self.view.bounds, TAP_AREA_SIZE, TAP_AREA_SIZE);
			if (CGRectContainsPoint(areaRect, point) == false) return;
		}
		
		// Hide
		[mainToolbar hideToolbar];
		[mainPagebar hidePagebar];
		self.lastHideTime = [NSDate new];
	}
}

#pragma mark - ReaderMainToolbarDelegate methods

- (void)tappedInToolbar:(ReaderMainToolbar *)toolbar doneButton:(UIButton *)button
{
	DXLog(@"");

#if !READER_STANDALONE
	[document saveReaderDocument]; // Save any ReaderDocument object changes
	[[ReaderThumbQueue sharedInstance] cancelOperationsWithGUID:document.guid];
	[[ReaderThumbCache sharedInstance] removeAllObjects]; // Empty the thumb cache

	if (printInteraction != nil) [printInteraction dismissAnimated:NO]; // Dismiss

	if ([delegate respondsToSelector:@selector(dismissReaderViewController:)] == YES)
	{
		[delegate dismissReaderViewController:self]; // Dismiss the ReaderViewController
	}
	else // We have a "Delegate must respond to -dismissReaderViewController: error"
	{
		NSAssert(NO, @"Delegate must respond to -dismissReaderViewController:");
	}
#endif
}

- (void)tappedInToolbar:(ReaderMainToolbar *)toolbar thumbsButton:(UIButton *)button
{
	DXLog(@"");

	if (printInteraction != nil) [printInteraction dismissAnimated:NO]; // Dismiss
	
	ThumbsViewController *thumbsViewController = [[ThumbsViewController alloc] initWithReaderDocument:document];
	thumbsViewController.delegate = self;
	thumbsViewController.title = self.title;
	thumbsViewController.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
	thumbsViewController.modalPresentationStyle = UIModalPresentationFullScreen;
	
	[self presentModalViewController:thumbsViewController animated:NO];
}

- (void)tappedInToolbar:(ReaderMainToolbar *)toolbar printButton:(UIButton *)button
{
	DXLog(@"");
	
#if READER_ENABLE_PRINT
	Class printInteractionController = NSClassFromString(@"UIPrintInteractionController");

	if ((printInteractionController != nil) && [printInteractionController isPrintingAvailable])
	{
		NSData *pdfData = [self documentData];
		printInteraction = [printInteractionController sharedPrintController];
		if ([printInteractionController canPrintData:pdfData] == YES) {
			UIPrintInfo *printInfo = [NSClassFromString(@"UIPrintInfo") printInfo];
			
			printInfo.duplex = UIPrintInfoDuplexLongEdge;
			printInfo.outputType = UIPrintInfoOutputGeneral;
			printInfo.jobName = document.fileName;
			
			printInteraction.printInfo = printInfo;
			printInteraction.printingItem = pdfData;
			printInteraction.showsPageRange = YES;
			
			if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
			{
				[printInteraction presentFromRect:button.bounds inView:button animated:YES completionHandler:
					^(UIPrintInteractionController *pic, BOOL completed, NSError *error)
					{
						#ifdef DEBUG
							if ((completed == NO) && (error != nil)) NSLog(@"%s %@", __FUNCTION__, error);
						#endif
					}
				];
			}
			else // Presume UIUserInterfaceIdiomPhone
			{
				[printInteraction presentAnimated:YES completionHandler:
					^(UIPrintInteractionController *pic, BOOL completed, NSError *error)
					{
						#ifdef DEBUG
							if ((completed == NO) && (error != nil)) NSLog(@"%s %@", __FUNCTION__, error);
						#endif
					}
				];
			}
		}
		else {
			NSLog(@"Cannot print this PDF data!");
		}
	}
#endif
}

- (void)tappedInToolbar:(ReaderMainToolbar *)toolbar emailButton:(UIButton *)button
{
	DXLog(@"");

#if READER_ENABLE_MAIL
	if ([MFMailComposeViewController canSendMail] == NO) {
		return;
	}
	if (printInteraction != nil) {
		[printInteraction dismissAnimated:YES];
	}
	
	// attach the PDF if it's not too big
	NSData *attachment = [self documentData];
	if (attachment && [attachment length] < (unsigned long long)15728640) {		// Check attachment size limit (15MB)
		NSString *fileName = document.fileName;
		
		MFMailComposeViewController *mailComposer = [MFMailComposeViewController new];
		[mailComposer addAttachmentData:attachment mimeType:@"application/pdf" fileName:fileName];
		[mailComposer setSubject:fileName]; // Use the document file name for the subject
		
		mailComposer.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
		mailComposer.modalPresentationStyle = UIModalPresentationFormSheet;
		mailComposer.mailComposeDelegate = self; // Set the delegate
		
		[self presentModalViewController:mailComposer animated:YES];
	}
	else if (attachment) {
		NSLog(@"PDF is too big: %d KB", [attachment length] / 1024);
	}
	else {
		NSLog(@"Did not get data!");
	}
#endif
}

- (void)tappedInToolbar:(ReaderMainToolbar *)toolbar markButton:(UIButton *)button
{
	DXLog(@"");

	if (printInteraction != nil) [printInteraction dismissAnimated:YES];

	NSInteger page = [document.pageNumber integerValue];
	if ([document.bookmarks containsIndex:page])
	{
		[mainToolbar setBookmarkState:NO];
		[document.bookmarks removeIndex:page];
	}
	else // Add the bookmarked page index
	{
		[mainToolbar setBookmarkState:YES];
		[document.bookmarks addIndex:page];
	}
}

#pragma mark - MFMailComposeViewControllerDelegate methods

- (void)mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error
{
	DXLog(@"");
	
	#ifdef DEBUG
		if ((result == MFMailComposeResultFailed) && (error != NULL)) NSLog(@"%@", error);
	#endif
	
	[self dismissModalViewControllerAnimated:YES]; // Dismiss
}

#pragma mark - ThumbsViewControllerDelegate methods

- (void)dismissThumbsViewController:(ThumbsViewController *)viewController
{
	DXLog(@"");

	[self updateToolbarBookmarkIcon]; // Update bookmark icon
	[self dismissModalViewControllerAnimated:NO]; // Dismiss
}

- (void)thumbsViewController:(ThumbsViewController *)viewController gotoPage:(NSInteger)page
{
	DXLog(@"");

	[self showDocumentPage:page]; // Show the page
}

#pragma mark - ReaderMainPagebarDelegate methods

- (void)pagebar:(ReaderMainPagebar *)pagebar gotoPage:(NSInteger)page
{
	DXLog(@"");

	[self showDocumentPage:page]; // Show the page
}

#pragma mark - UIApplication notification methods

- (void)applicationWill:(NSNotification *)notification
{
	DXLog(@"");
	
	[document saveReaderDocument]; // Save any ReaderDocument object changes
	
	if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
	{
		if (printInteraction != nil) [printInteraction dismissAnimated:NO];
	}
}

@end
