//
//	ReaderThumbCache.m
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

#import "ReaderThumbCache.h"
#import "ReaderThumbQueue.h"
#import "ReaderThumbFetch.h"
#import "ReaderThumbView.h"

#define CACHE_SIZE 2 * 1024 * 1024


@implementation ReaderThumbCache


+ (ReaderThumbCache *)sharedInstance
{
	static dispatch_once_t predicate = 0;
	static ReaderThumbCache *object = nil; // Object
	dispatch_once(&predicate, ^{ object = [self new]; });
	
	return object; // ReaderThumbCache singleton
}

+ (NSString *)appCachesPath
{
	static dispatch_once_t predicate = 0;
	static NSString *theCachesPath = nil; // Application caches path string
	
	dispatch_once(&predicate, // Save a copy of the application caches path the first time it is needed
	^{
		NSArray *cachesPaths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
		theCachesPath = [[cachesPaths objectAtIndex:0] copy]; // Keep a copy for later abusage
	});
	
	return theCachesPath;
}

+ (NSString *)thumbCachePathForGUID:(NSString *)guid
{
	NSString *cachesPath = [ReaderThumbCache appCachesPath];
	
	return [cachesPath stringByAppendingPathComponent:guid];
}

+ (void)createThumbCacheWithGUID:(NSString *)guid
{
	NSFileManager *fileManager = [NSFileManager new];
	NSString *cachePath = [ReaderThumbCache thumbCachePathForGUID:guid];
	[fileManager createDirectoryAtPath:cachePath withIntermediateDirectories:NO attributes:nil error:NULL];
}

+ (void)removeThumbCacheWithGUID:(NSString *)guid
{
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
		NSFileManager *fileManager = [NSFileManager new];
		NSString *cachePath = [ReaderThumbCache thumbCachePathForGUID:guid];
		[fileManager removeItemAtPath:cachePath error:NULL]; // Remove thumb cache directory
	});
}

+ (void)touchThumbCacheWithGUID:(NSString *)guid
{
	NSFileManager *fileManager = [NSFileManager new];
	NSString *cachePath = [ReaderThumbCache thumbCachePathForGUID:guid];
	NSDictionary *attributes = [NSDictionary dictionaryWithObject:[NSDate date] forKey:NSFileModificationDate];
	[fileManager setAttributes:attributes ofItemAtPath:cachePath error:NULL]; // New modification date
}

+ (void)purgeThumbCachesOlderThan:(NSTimeInterval)age
{
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
		NSDate *now = [NSDate date];
		NSString *cachesPath = [ReaderThumbCache appCachesPath];
		NSFileManager *fileManager = [NSFileManager new];
		
		NSArray *cachesList = [fileManager contentsOfDirectoryAtPath:cachesPath error:NULL];
		if (cachesList != nil) {
			for (NSString *cacheName in cachesList) // Enumerate directory contents
			{
				if (cacheName.length == 36) // This is a very hacky cache ident kludge
				{
					NSString *cachePath = [cachesPath stringByAppendingPathComponent:cacheName];
					NSDictionary *attributes = [fileManager attributesOfItemAtPath:cachePath error:NULL];
					NSDate *cacheDate = [attributes objectForKey:NSFileModificationDate]; // Cache date
					
					NSTimeInterval seconds = [now timeIntervalSinceDate:cacheDate]; // Cache age
					if (seconds > age) {
						[fileManager removeItemAtPath:cachePath error:NULL];
					}
				}
			}
		}
	});
}

#pragma mark ReaderThumbCache instance methods

- (id)init
{
	if ((self = [super init])) {
		thumbCache = [NSCache new];
		[thumbCache setName:@"ReaderThumbCache"];
		[thumbCache setTotalCostLimit:CACHE_SIZE];
	}
	
	return self;
}

- (void)dealloc
{
	thumbCache = nil;
}

- (id)thumbRequest:(ReaderThumbRequest *)request priority:(BOOL)priority
{
	@synchronized(thumbCache) {
		id cached = [thumbCache objectForKey:request.cacheKey];
		if (!cached) {
			ReaderThumbFetch *thumbFetch = [[ReaderThumbFetch alloc] initWithRequest:request];
			request.thumbView.operation = thumbFetch;				// what is this good for?
			
			[thumbFetch setQueuePriority:(priority ? NSOperationQueuePriorityNormal : NSOperationQueuePriorityLow)]; // Queue priority
			
			[[ReaderThumbQueue sharedInstance] addLoadOperation:thumbFetch];
		}
		
		return cached; // nil or UIImage
	}
}

- (void)setObject:(UIImage *)image forKey:(NSString *)key
{
	if (image && [key length] > 0) {
		@synchronized(thumbCache) {
			NSUInteger bytes = (NSUInteger)(image.size.width * image.size.height * 4.0f);
			[thumbCache setObject:image forKey:key cost:bytes]; // Cache image
		}
	}
}

- (void)removeObjectForKey:(NSString *)key
{
	@synchronized(thumbCache) {
		[thumbCache removeObjectForKey:key];
	}
}

- (void)removeAllObjects
{
	@synchronized(thumbCache) {
		[thumbCache removeAllObjects];
	}
}

@end
