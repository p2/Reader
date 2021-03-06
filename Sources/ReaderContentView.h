//
//	ReaderContentView.h
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

#import "ReaderContentPage.h"
#import "ReaderThumbView.h"

@class ReaderContentView;
@class ReaderContentPage;
@class ReaderContentThumb;

@protocol ReaderContentViewDelegate <NSObject>

@required
- (void)contentView:(ReaderContentView *)contentView touchesBegan:(NSSet *)touches;

@optional
- (void)contentViewDidZoom:(ReaderContentView *)contentView;
- (void)contentViewDidPan:(ReaderContentView *)contentView;

@end

@interface ReaderContentView : UIScrollView <UIScrollViewDelegate>

@property (nonatomic, weak, readwrite) id <ReaderContentViewDelegate> message;
@property (nonatomic, readonly, strong) ReaderContentPage *contentPage;
@property (nonatomic, readonly, strong) ReaderContentThumb *thumbView;
@property (nonatomic, readonly, strong) UIView *containerView;

/**
 *	Convenience initializer using `ReaderContentPage` as class.
 *	@param frame The frame to be used
 *	@param fileURL The URL to the PDF file
 *	@param page The page of the PDF we want to show
 *	@param phrase The password to use for the PDF, if any
 */
- (id)initWithFrame:(CGRect)frame fileURL:(NSURL *)fileURL page:(NSUInteger)page password:(NSString *)phrase;

/**
 *	The designated initializer
 *	@param frame The frame to be used
 *	@param fileURL The URL to the PDF file
 *	@param page The page of the PDF we want to show
 *	@param aClass The class to use for the contentPage, must be a subclass of "ReaderContentPage", which is automatically chosen if it is nil
 *	@param phrase The password to use for the PDF, if any
 */
- (id)initWithFrame:(CGRect)frame fileURL:(NSURL *)fileURL page:(NSUInteger)page contentPageClass:(Class)aClass password:(NSString *)phrase;

- (void)showPageThumb:(NSURL *)fileURL page:(NSInteger)page password:(NSString *)phrase guid:(NSString *)guid;
- (id)singleTap:(UITapGestureRecognizer *)recognizer;

- (BOOL)zoomIncrementAnimated:(BOOL)animated;
- (BOOL)zoomDecrementAnimated:(BOOL)animated;
- (void)zoomResetAnimated:(BOOL)animated;

@end


#pragma mark -

@interface ReaderContentThumb : ReaderThumbView

@end
