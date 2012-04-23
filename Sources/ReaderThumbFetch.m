//
//	ReaderThumbFetch.m
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

#import "ReaderThumbFetch.h"
#import "ReaderThumbRender.h"
#import "ReaderThumbCache.h"
#import "ReaderThumbView.h"
#import "CGPDFDocument.h"

#import <ImageIO/ImageIO.h>

@implementation ReaderThumbFetch

//#pragma mark Properties

//@synthesize ;

#pragma mark ReaderThumbFetch instance methods

- (id)initWithRequest:(ReaderThumbRequest *)object
{
	if ((self = [super initWithGUID:object.guid])) {
		request = object;
	}
	return self;
}

- (void)dealloc
{
	if (request.thumbView.operation == self) {
		request.thumbView.operation = nil;
	}
	request = nil;
}

- (NSURL *)thumbFileURL
{
	NSString *cachePath = [ReaderThumbCache thumbCachePathForGUID:request.guid];
	NSString *fileName = [NSString stringWithFormat:@"%@.png", request.thumbName]; // Thumb file name
	
	return [NSURL fileURLWithPath:[cachePath stringByAppendingPathComponent:fileName]];
}

- (void)main
{
	DXLog(@"");
	if (self.isCancelled) {
		return;
	}
	
	[[NSThread currentThread] setName:@"ReaderThumbFetch"];		// is this needed?
	
	NSURL *thumbURL = [self thumbFileURL];
	CGImageRef imageRef = NULL;
	CGImageSourceRef loadRef = CGImageSourceCreateWithURL((__bridge CFURLRef)thumbURL, NULL);
	
	// Load the existing thumb image
	if (loadRef != NULL) {
		imageRef = CGImageSourceCreateImageAtIndex(loadRef, 0, NULL);
		CFRelease(loadRef); // Release CGImageSource reference
		
		if (imageRef != NULL) {
			UIImage *image = [UIImage imageWithCGImage:imageRef scale:request.scale orientation:0];
			CGImageRelease(imageRef); // Release the CGImage reference from the above thumb load code
			
			[[ReaderThumbCache sharedInstance] setObject:image forKey:request.cacheKey]; // Update cache
			
			// Show the image in the target thumb view on the main thread
			if (!self.isCancelled) {
				ReaderThumbView *thumbView = request.thumbView;
				NSUInteger targetTag = request.targetTag;
				
				// Queue image show on main thread
				dispatch_async(dispatch_get_main_queue(), ^{
					if (thumbView.targetTag == targetTag) {
						[thumbView showImage:image];
					}
				});
			}
		}
	}
	
	// Existing thumb image not found - so create and queue up a thumb render operation on the work queue
	else {
		ReaderThumbRender *thumbRender = [[ReaderThumbRender alloc] initWithRequest:request];
		[thumbRender setQueuePriority:self.queuePriority];
		[thumbRender setThreadPriority:(self.threadPriority - 0.1)];
		
		if (!self.isCancelled) {
			request.thumbView.operation = thumbRender; // Update the thumb view operation property to the new operation
			[[ReaderThumbQueue sharedInstance] addWorkOperation:thumbRender];
		}
	}
}

@end
