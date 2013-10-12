//
//	ReaderContentPage.m
//	Reader v2.5.6
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

#import "ReaderContentPage.h"
#import "ReaderContentTile.h"
#import "CGPDFDocument.h"


@interface ReaderContentPage ()

@property (nonatomic, readwrite, strong) NSMutableArray *links;

@end


@implementation ReaderContentPage

@synthesize links = _links;


- (void)dealloc
{
	@synchronized(self) {		// Block any other threads
		CGPDFPageRelease(_PDFPageRef),
		_PDFPageRef = NULL;
		CGPDFDocumentRelease(_PDFDocRef),
		_PDFDocRef = NULL;
	}
}


#pragma mark - Initialization
- (id)initWithFrame:(CGRect)frame
{
	if ((self = [super initWithFrame:frame])) {
		//self.autoresizesSubviews = NO;
		self.userInteractionEnabled = NO;
		self.clearsContextBeforeDrawing = NO;
		self.contentMode = UIViewContentModeRedraw;
		self.autoresizingMask = UIViewAutoresizingNone;
		self.backgroundColor = [UIColor clearColor];
	}
	
	return self;
}

- (id)initWithURL:(NSURL *)fileURL page:(NSInteger)page password:(NSString *)phrase
{
	NSParameterAssert(nil != fileURL);
	
	// determine needed frame
	[self updateViewRectWithURL:fileURL page:page password:phrase];
	
	CGRect viewRect = CGRectZero;
	NSInteger page_w = (NSInteger)_pageWidth;
	NSInteger page_h = (NSInteger)_pageHeight;
	if (page_w % 2) {
		page_w--;
	}
	if (page_h % 2) {
		page_h--;
	}
	viewRect.size = CGSizeMake(page_w, page_h);
	
	// initialize
	if ((self = [self initWithFrame:viewRect])) {
		[self buildAnnotationLinksList];
	}
	return self;
}


#pragma mark - Properties
- (CGRect)pageRect
{
	return CGRectMake(_pageOffsetX, _pageOffsetY, _pageWidth, _pageHeight);
}

- (void)updateViewRectWithURL:(NSURL *)fileURL page:(NSInteger)page password:(NSString *)phrase
{
	// read the PDF
	_PDFDocRef = CGPDFDocumentCreateX((__bridge CFURLRef)fileURL, phrase);
	NSAssert(NULL != _PDFDocRef, @"Failed to create PDF reference from %@", fileURL);
	
	// check page bounds
	if (page < 1) {
		page = 1;
	}
	
	NSInteger numPages = CGPDFDocumentGetNumberOfPages(_PDFDocRef);
	if (page > numPages) {
		page = numPages;
	}
	
	// Get page
	_PDFPageRef = CGPDFDocumentGetPage(_PDFDocRef, page);
	NSAssert(NULL != _PDFPageRef, @"CGPDFDocumentGetPage failed to get page %d", page);
	
	CGPDFPageRetain(_PDFPageRef);
	
	CGRect cropBoxRect = CGPDFPageGetBoxRect(_PDFPageRef, kCGPDFCropBox);
	CGRect mediaBoxRect = CGPDFPageGetBoxRect(_PDFPageRef, kCGPDFMediaBox);
	CGRect effectiveRect = CGRectIntersection(cropBoxRect, mediaBoxRect);
	_pageAngle = CGPDFPageGetRotationAngle(_PDFPageRef);
	
	// Page rotation angle (in degrees)
	switch (_pageAngle) {
		default:
		case 0:
		case 180:
		{
			_pageWidth = effectiveRect.size.width;
			_pageHeight = effectiveRect.size.height;
			_pageOffsetX = effectiveRect.origin.x;
			_pageOffsetY = effectiveRect.origin.y;
			break;
		}
			
		case 90:
		case 270:
		{
			_pageWidth = effectiveRect.size.height;
			_pageHeight = effectiveRect.size.width;
			_pageOffsetX = effectiveRect.origin.y;
			_pageOffsetY = effectiveRect.origin.x;
			break;
		}
	}
	
	_page = page;
}


#pragma mark - ReaderContentPage class methods
+ (Class)layerClass
{
	return [ReaderContentTile class];
}


#pragma mark ReaderContentPage PDF link methods
/**
 *  Add highlight views over all links.
 */
- (void)highlightPageLinks
{
	if (_links.count > 0) {
		UIColor *hilite = [UIColor colorWithRed:0.0f green:0.0f blue:1.0f alpha:0.15f];
		for (ReaderDocumentLink *link in _links) {
			UIView *highlight = [[UIView alloc] initWithFrame:link.rect];
			highlight.autoresizesSubviews = NO;
			highlight.userInteractionEnabled = NO;
			highlight.clearsContextBeforeDrawing = NO;
			highlight.contentMode = UIViewContentModeRedraw;
			highlight.autoresizingMask = UIViewAutoresizingNone;
			highlight.backgroundColor = hilite; // Color
			
			[self addSubview:highlight]; 
		}
	}
}

- (ReaderDocumentLink *)linkFromAnnotation:(CGPDFDictionaryRef)annotationDictionary
{
	ReaderDocumentLink *documentLink = nil;
	CGPDFArrayRef annotationRectArray = NULL;
	
	if (CGPDFDictionaryGetArray(annotationDictionary, "Rect", &annotationRectArray)){
		CGPDFReal ll_x = 0.0f;
		CGPDFReal ll_y = 0.0f;
		CGPDFReal ur_x = 0.0f;
		CGPDFReal ur_y = 0.0f;
		
		CGPDFArrayGetNumber(annotationRectArray, 0, &ll_x); // Lower-left X co-ordinate
		CGPDFArrayGetNumber(annotationRectArray, 1, &ll_y); // Lower-left Y co-ordinate
		
		CGPDFArrayGetNumber(annotationRectArray, 2, &ur_x); // Upper-right X co-ordinate
		CGPDFArrayGetNumber(annotationRectArray, 3, &ur_y); // Upper-right Y co-ordinate
		
		// Normalize Xs
		if (ll_x > ur_x) {
			CGPDFReal t = ll_x;
			ll_x = ur_x;
			ur_x = t;
		}
		
		// Normalize Ys
		if (ll_y > ur_y) {
			CGPDFReal t = ll_y;
			ll_y = ur_y;
			ur_y = t;
		}
		
		// offset coordinates
		ll_x -= _pageOffsetX;
		ll_y -= _pageOffsetY;
		ur_x -= _pageOffsetX;
		ur_y -= _pageOffsetY;
		
		// is page rotated?
		switch (_pageAngle) {
			case 90: {
				CGPDFReal swap;
				swap = ll_y; ll_y = ll_x; ll_x = swap;
				swap = ur_y; ur_y = ur_x; ur_x = swap;
				break;
			}
				
			case 270: {
				CGPDFReal swap;
				swap = ll_y; ll_y = ll_x; ll_x = swap;
				swap = ur_y; ur_y = ur_x; ur_x = swap;
				ll_x = ((0.0f - ll_x) + _pageWidth);
				ur_x = ((0.0f - ur_x) + _pageWidth);
				break;
			}
				
			case 0: {
				ll_y = ((0.0f - ll_y) + _pageHeight);
				ur_y = ((0.0f - ur_y) + _pageHeight);
				break;
			}
		}
		
		CGFloat vr_x = roundf(ll_x);
		CGFloat vr_w = roundf(ur_x - ll_x);
		CGFloat vr_y = roundf(ll_y);
		CGFloat vr_h = roundf(ur_y - ll_y);
		
		CGRect viewRect = CGRectMake(vr_x, vr_y, vr_w, vr_h); // View CGRect from PDFRect
		
		documentLink = [ReaderDocumentLink newWithRect:viewRect dictionary:annotationDictionary];
	}
	
	return documentLink;
}

- (void)buildAnnotationLinksList
{
	self.links = [NSMutableArray new];
	
	CGPDFArrayRef pageAnnotations = NULL;
	CGPDFDictionaryRef pageDictionary = CGPDFPageGetDictionary(_PDFPageRef);
	if (CGPDFDictionaryGetArray(pageDictionary, "Annots", &pageAnnotations) == true) {
		NSInteger count = CGPDFArrayGetCount(pageAnnotations);							// Number of annotations
		
		// Iterate through all annotations
		for (NSInteger index = 0; index < count; index++) {
			CGPDFDictionaryRef annotationDictionary = NULL;
			if (CGPDFArrayGetDictionary(pageAnnotations, index, &annotationDictionary) == true) {
				const char *annotationSubtype = NULL;
				if (CGPDFDictionaryGetName(annotationDictionary, "Subtype", &annotationSubtype) == true) {
					
					// Found annotation subtype of 'Link'
					if (strcmp(annotationSubtype, "Link") == 0) {
						ReaderDocumentLink *documentLink = [self linkFromAnnotation:annotationDictionary];
						if (documentLink != nil) {
							[_links insertObject:documentLink atIndex:0];				// Add link
						}
					}
				}
			}
		}
		
//		[self highlightPageLinks]; // For link support debugging
	}
}

- (CGPDFArrayRef)destinationWithName:(const char *)destinationName inDestsTree:(CGPDFDictionaryRef)node
{
	CGPDFArrayRef destinationArray = NULL;
	CGPDFArrayRef limitsArray = NULL;
	
	// "Limits"
	if (CGPDFDictionaryGetArray(node, "Limits", &limitsArray) == true) {
		CGPDFStringRef lowerLimit = NULL; CGPDFStringRef upperLimit = NULL;
		if (CGPDFArrayGetString(limitsArray, 0, &lowerLimit) == true) {				// Lower limit
			if (CGPDFArrayGetString(limitsArray, 1, &upperLimit) == true) {			// Upper limit
				const char *ll = (const char *)CGPDFStringGetBytePtr(lowerLimit);	// Lower string
				const char *ul = (const char *)CGPDFStringGetBytePtr(upperLimit);	// Upper string
				
				// Destination name is outside this node's limits
				if ((strcmp(destinationName, ll) < 0) || (strcmp(destinationName, ul) > 0)) {
					return NULL;
				}
			}
		}
	}
	
	// "Names"
	CGPDFArrayRef namesArray = NULL;
	if (CGPDFDictionaryGetArray(node, "Names", &namesArray) == true) {
		NSInteger namesCount = CGPDFArrayGetCount(namesArray);
		for (NSInteger index = 0; index < namesCount; index += 2) {
			CGPDFStringRef destName; // Destination name string
			
			if (CGPDFArrayGetString(namesArray, index, &destName) == true) {
				const char *dn = (const char *)CGPDFStringGetBytePtr(destName);
				
				// Found the destination name
				if (strcmp(dn, destinationName) == 0) {
					if (CGPDFArrayGetArray(namesArray, (index + 1), &destinationArray) == false) {
						CGPDFDictionaryRef destinationDictionary = NULL;
						
						if (CGPDFArrayGetDictionary(namesArray, (index + 1), &destinationDictionary) == true) {
							CGPDFDictionaryGetArray(destinationDictionary, "D", &destinationArray);
						}
					}
					
					return destinationArray; // Return the destination array
				}
			}
		}
	}
	
	// "Kids"
	CGPDFArrayRef kidsArray = NULL;
	if (CGPDFDictionaryGetArray(node, "Kids", &kidsArray) == true) {
		NSInteger kidsCount = CGPDFArrayGetCount(kidsArray);
		for (NSInteger index = 0; index < kidsCount; index++) {
			CGPDFDictionaryRef kidNode = NULL;
			
			// Recurse into node
			if (CGPDFArrayGetDictionary(kidsArray, index, &kidNode) == true) {
				destinationArray = [self destinationWithName:destinationName inDestsTree:kidNode];
				if (destinationArray != NULL) {
					return destinationArray;
				}
			}
		}
	}
	
	return NULL;
}

- (id)annotationLinkTarget:(CGPDFDictionaryRef)annotationDictionary
{
	id linkTarget = nil;
	
	CGPDFStringRef destName = NULL; const char *destString = NULL;
	CGPDFDictionaryRef actionDictionary = NULL; CGPDFArrayRef destArray = NULL;
	if (CGPDFDictionaryGetDictionary(annotationDictionary, "A", &actionDictionary) == true) {
		
		// Annotation action type string
		const char *actionType = NULL;
		if (CGPDFDictionaryGetName(actionDictionary, "S", &actionType) == true) {
			
			// GoTo action type
			if (strcmp(actionType, "GoTo") == 0) {
				if (CGPDFDictionaryGetArray(actionDictionary, "D", &destArray) == false) {
					CGPDFDictionaryGetString(actionDictionary, "D", &destName);
				}
			}
			
			// Handle other link action type possibility
			else {
				
				// URI action type
				if (strcmp(actionType, "URI") == 0) {
					CGPDFStringRef uriString = NULL;
					
					if (CGPDFDictionaryGetString(actionDictionary, "URI", &uriString) == true) {
						const char *uri = (const char *)CGPDFStringGetBytePtr(uriString);
						NSString *linkString = [NSString stringWithCString:uri encoding:NSASCIIStringEncoding];
						linkTarget = [NSURL URLWithString:linkString];
					}
				}
			}
		}
	}
	
	// Handle other link target possibilities
	else {
		if (CGPDFDictionaryGetArray(annotationDictionary, "Dest", &destArray) == false) {
			if (CGPDFDictionaryGetString(annotationDictionary, "Dest", &destName) == false) {
				CGPDFDictionaryGetName(annotationDictionary, "Dest", &destString);
			}
		}
	}
	
	// Handle a destination name
	if (destName != NULL) {
		CGPDFDictionaryRef catalogDictionary = CGPDFDocumentGetCatalog(_PDFDocRef);
		
		// Destination names in the document
		CGPDFDictionaryRef namesDictionary = NULL;
		if (CGPDFDictionaryGetDictionary(catalogDictionary, "Names", &namesDictionary) == true) {
			CGPDFDictionaryRef destsDictionary = NULL;
			
			if (CGPDFDictionaryGetDictionary(namesDictionary, "Dests", &destsDictionary) == true) {
				const char *destinationName = (const char *)CGPDFStringGetBytePtr(destName);
				destArray = [self destinationWithName:destinationName inDestsTree:destsDictionary];
			}
		}
	}
	
	// Handle a destination string
	if (destString != NULL) {
		CGPDFDictionaryRef catalogDictionary = CGPDFDocumentGetCatalog(_PDFDocRef);
		CGPDFDictionaryRef destsDictionary = NULL; // Document destinations dictionary
		
		if (CGPDFDictionaryGetDictionary(catalogDictionary, "Dests", &destsDictionary) == true) {
			CGPDFDictionaryRef targetDictionary = NULL;
			
			if (CGPDFDictionaryGetDictionary(destsDictionary, destString, &targetDictionary) == true) {
				CGPDFDictionaryGetArray(targetDictionary, "D", &destArray);
			}
		}
	}
	
	// Handle a destination array
	if (destArray != NULL) {
		NSInteger targetPageNumber = 0;
		CGPDFDictionaryRef pageDictionaryFromDestArray = NULL;
		
		if (CGPDFArrayGetDictionary(destArray, 0, &pageDictionaryFromDestArray) == true) {
			NSInteger pageCount = CGPDFDocumentGetNumberOfPages(_PDFDocRef);
			
			for (NSInteger pageNumber = 1; pageNumber <= pageCount; pageNumber++) {
				CGPDFPageRef pageRef = CGPDFDocumentGetPage(_PDFDocRef, pageNumber);
				CGPDFDictionaryRef pageDictionaryFromPage = CGPDFPageGetDictionary(pageRef);
				
				// Found it
				if (pageDictionaryFromPage == pageDictionaryFromDestArray) {
					targetPageNumber = pageNumber; break;
				}
			}
		}
		
		// Try page number from array possibility
		else {
			CGPDFInteger pageNumber = 0; // Page number in array
			
			if (CGPDFArrayGetInteger(destArray, 0, &pageNumber) == true) {
				targetPageNumber = (pageNumber + 1); // 1-based
			}
		}
		
		// We have a target page number
		if (targetPageNumber > 0) {
			linkTarget = [NSNumber numberWithInteger:targetPageNumber];
		}
	}
	
	return linkTarget;
}

/**
 *  Handle a single tap.
 */
- (id)singleTap:(UITapGestureRecognizer *)recognizer
{
	if (recognizer.state == UIGestureRecognizerStateRecognized) {
		
		// if we have links...
		if ([_links count] > 0) {
			CGPoint point = [recognizer locationInView:self];
			
			// ...loop through to find the tapped one
			for (ReaderDocumentLink *link in _links) {
				if (CGRectContainsPoint(link.rect, point)) {
					return [self annotationLinkTarget:link.dictionary];
				}
			}
		}
	}
	
	return nil;
}


#pragma mark - CATiledLayer delegate methods

/**
 *  The PDF is drawn with constant aspect ratio, centered in the view's bounds with the wider edges aligning with the bounds edges.
 */
- (void)drawLayer:(CATiledLayer *)layer inContext:(CGContextRef)context
{
	// Block any other threads
	CGPDFPageRef drawPDFPageRef = NULL;
	CGPDFDocumentRef drawPDFDocRef = NULL;
	@synchronized(self) {
		drawPDFDocRef = CGPDFDocumentRetain(_PDFDocRef);
		drawPDFPageRef = CGPDFPageRetain(_PDFPageRef);
	}
	
	CGContextSetRGBFillColor(context, 1.0f, 1.0f, 1.0f, 1.0f);			// White
	CGContextFillRect(context, CGContextGetClipBoundingBox(context));
	
	// Go ahead and render the PDF page into the context
	if (drawPDFPageRef != NULL) {
		CGContextSaveGState(context);
		
		CGContextTranslateCTM(context, 0.0f, self.bounds.size.height);
		CGContextScaleCTM(context, 1.0f, -1.0f);
		CGContextConcatCTM(context, CGPDFPageGetDrawingTransform(drawPDFPageRef, kCGPDFCropBox, self.bounds, 0, true));		// draw centered with constant aspect ratio
		CGContextSetRenderingIntent(context, kCGRenderingIntentDefault);
		CGContextSetInterpolationQuality(context, kCGInterpolationDefault);
		CGContextDrawPDFPage(context, drawPDFPageRef);
		
		CGContextRestoreGState(context);
	}
	
	// Cleanup
	CGPDFPageRelease(drawPDFPageRef);
	CGPDFDocumentRelease(drawPDFDocRef);
}

@end

#pragma mark -



/**
 *  ReaderDocumentLink class implementation.
 */
@implementation ReaderDocumentLink

#pragma mark Properties

@synthesize rect = _rect;
@synthesize dictionary = _dictionary;

#pragma mark ReaderDocumentLink class methods

+ (id)newWithRect:(CGRect)linkRect dictionary:(CGPDFDictionaryRef)linkDictionary
{
	return [[ReaderDocumentLink alloc] initWithRect:linkRect dictionary:linkDictionary];
}

#pragma mark ReaderDocumentLink instance methods

- (id)initWithRect:(CGRect)linkRect dictionary:(CGPDFDictionaryRef)linkDictionary
{
	if ((self = [super init])) {
		_dictionary = linkDictionary;
		_rect = linkRect;
	}
	
	return self;
}


@end
