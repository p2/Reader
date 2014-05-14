//
//	ReaderViewController.h
//	Reader v2.5.4
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

#import <UIKit/UIKit.h>
#import <MessageUI/MessageUI.h>

#import "ReaderDocument.h"
#import "ReaderContentView.h"
#import "ReaderMainPagebar.h"
#import "ThumbsViewController.h"


@class ReaderViewController;

@protocol ReaderViewControllerDelegate <NSObject>

@optional
- (void)dismissReaderViewController:(ReaderViewController *)viewController;

@end


@interface ReaderViewController : UIViewController <UIScrollViewDelegate, UIGestureRecognizerDelegate, UIDocumentInteractionControllerDelegate,
													ReaderMainPagebarDelegate, ReaderContentViewDelegate, ThumbsViewControllerDelegate>
{
@private
	UIPrintInteractionController *printInteraction;
	
	CGSize lastAppearSize;
	BOOL isVisible;
}

@property (nonatomic, weak, readwrite) id <ReaderViewControllerDelegate> delegate;
@property (nonatomic, strong, readonly) ReaderDocument *document;

@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) ReaderMainPagebar *mainPagebar;
@property (nonatomic, strong) NSMutableDictionary *contentViews;

@property (nonatomic, readonly, assign) ReaderContentView *currentPageView;
@property (nonatomic, readonly, assign) NSUInteger currentPage;
@property (nonatomic, readonly, strong) NSDate *lastHideTime;

+ (UINavigationController *)presentableViewControllerForDocument:(ReaderDocument *)document withDelegate:(id<ReaderViewControllerDelegate>)delegate;

- (id)initWithReaderDocument:(ReaderDocument *)object;
- (void)showDocument:(id)object;

- (void)didAddContentView:(ReaderContentView *)aContentView forPage:(NSUInteger)pageNumber;
- (NSData *)documentDataFor:(ReaderContentTargetType)dataType;

- (BOOL)toolbarsHidden;
- (void)showToolbarsAnimated:(BOOL)animated;
- (void)hideToolbarsAnimated:(BOOL)animated;

- (void)handleSingleTap:(UITapGestureRecognizer *)recognizer;
- (void)handleDoubleTap:(UITapGestureRecognizer *)recognizer;
- (void)handleLongPress:(UILongPressGestureRecognizer *)recognizer;

- (Class)classForViewPages;


@end
