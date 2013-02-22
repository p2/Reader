//
//	ReaderDocument.m
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

#import "ReaderDocument.h"
#import "CGPDFDocument.h"
#import <fcntl.h>

@interface ReaderDocument ()

@property (nonatomic, readwrite, copy) NSString *guid;
@property (nonatomic, readwrite, strong) NSDate *fileDate;
@property (nonatomic, readwrite, copy) NSString *fileName;
@property (nonatomic, readwrite, strong) NSURL *fileURL;

@property (nonatomic, readwrite, strong) NSNumber *fileSize;
@property (nonatomic, readwrite, strong) NSNumber *pageCount;

@property (nonatomic, readwrite, strong) NSMutableIndexSet *bookmarks;
@property (nonatomic, readwrite, copy) NSString *password;

@end


@implementation ReaderDocument

#pragma mark Properties

@synthesize guid = _guid;
@synthesize fileDate = _fileDate;
@synthesize fileSize = _fileSize;
@synthesize pageCount = _pageCount;
@synthesize pageNumber = _pageNumber;
@synthesize bookmarks = _bookmarks;
@synthesize lastOpen = _lastOpen;
@synthesize password = _password;
@synthesize fileURL = _fileURL;
@synthesize fileName = _fileName;

#pragma mark - ReaderDocument class methods

+ (NSString *)GUID
{
	CFUUIDRef theUUID;
	CFStringRef theString;
	theUUID = CFUUIDCreate(NULL);
	theString = CFUUIDCreateString(NULL, theUUID);
	NSString *unique = [NSString stringWithString:(__bridge id)theString];
	
	CFRelease(theString);
	CFRelease(theUUID);
	
	return unique;
}

+ (NSString *)documentsPath
{
	NSArray *documentsPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	if ([documentsPaths count] > 0) {
		return [documentsPaths objectAtIndex:0]; // Path to the application's "~/Documents" directory
	}
	return nil;
}

+ (NSString *)applicationPath
{
	NSArray *documentsPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	if ([documentsPaths count] > 0) {
		return [[documentsPaths objectAtIndex:0] stringByDeletingLastPathComponent]; // Strip "Documents" component
	}
	return nil;
}

+ (NSString *)applicationSupportPath
{
	NSFileManager *fileManager = [NSFileManager new]; // File manager instance

	NSURL *pathURL = [fileManager URLForDirectory:NSApplicationSupportDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:NULL];
	return [pathURL path]; // Path to the application's "~/Library/Application Support" directory
}

+ (NSString *)relativeFilePath:(NSString *)fullFilePath
{
	assert(fullFilePath != nil); // Ensure that the full file path is not nil
	NSString *applicationPath = [ReaderDocument applicationPath]; // Get the application path
	NSRange range = [fullFilePath rangeOfString:applicationPath]; // Look for the application path
	assert(range.location != NSNotFound); // Ensure that the application path is in the full file path
	
	return [fullFilePath stringByReplacingCharactersInRange:range withString:@""]; // Strip it out
}

+ (NSString *)archiveFilePath:(NSString *)filename
{
	assert(filename != nil); // Ensure that the archive file name is not nil
	
	//NSString *archivePath = [ReaderDocument documentsPath]; // Application's "~/Documents" path
	NSString *archivePath = [ReaderDocument applicationSupportPath]; // Application's "~/Library/Application Support" path
	NSString *archiveName = [[filename stringByDeletingPathExtension] stringByAppendingPathExtension:@"plist"];
	
	return [archivePath stringByAppendingPathComponent:archiveName]; // "{archivePath}/'filename'.plist"
}

+ (ReaderDocument *)unarchiveFromFileName:(NSString *)filename password:(NSString *)phrase
{
	ReaderDocument *document = nil; // ReaderDocument object
	
	NSString *withName = [filename lastPathComponent];					// File name only
	NSString *archiveFilePath = [ReaderDocument archiveFilePath:withName];
	@try // Unarchive an archived ReaderDocument object from its property list
	{
		document = [NSKeyedUnarchiver unarchiveObjectWithFile:archiveFilePath];
		if ((document != nil) && (phrase != nil)) // Set the document password
		{
			[document setValue:[phrase copy] forKey:@"password"];
		}
	}
	@catch (NSException *exception) // Exception handling (just in case O_o)
	{
		#ifdef DEBUG
			NSLog(@"%s Caught %@: %@", __FUNCTION__, [exception name], [exception reason]);
		#endif
	}
	
	return document;
}

+ (ReaderDocument *)newWithDocumentFilePath:(NSString *)filePath password:(NSString *)phrase
{
	ReaderDocument *document = [ReaderDocument unarchiveFromFileName:filePath password:phrase];
	if (!document) {						// Unarchive failed so we create a new ReaderDocument object
		document = [[ReaderDocument alloc] initWithFilePath:filePath password:phrase];
	}
	
	return document;
}

+ (BOOL)isPDF:(NSString *)filePath
{
	BOOL state = NO;
	if (filePath != nil) // Must have a file path
	{
		const char *path = [filePath fileSystemRepresentation];
		int fd = open(path, O_RDONLY); // Open the file

		if (fd > 0) // We have a valid file descriptor
		{
			const unsigned char sig[4]; // File signature

			ssize_t len = read(fd, (void *)&sig, sizeof(sig));
			if (len == 4)
				if (sig[0] == '%')
					if (sig[1] == 'P')
						if (sig[2] == 'D')
							if (sig[3] == 'F')
								state = YES;
			close(fd); // Close the file
		}
	}

	return state;
}

#pragma mark - ReaderDocument instance methods

- (id)initWithFilePath:(NSString *)fullFilePath password:(NSString *)phrase
{
	id object = nil; // ReaderDocument object

	if ([ReaderDocument isPDF:fullFilePath] == YES) {						// File must exist
		if ((self = [super init])) {
			self.guid = [ReaderDocument GUID];								// Create a document GUID
			self.password = phrase;
			self.bookmarks = [NSMutableIndexSet new];						// Bookmarked pages index set
			self.pageNumber = [NSNumber numberWithInteger:1];				// Start page 1
			self.fileName = [ReaderDocument relativeFilePath:fullFilePath];
			
			CFURLRef docURLRef = (__bridge CFURLRef)[self fileURL];			// CFURLRef from NSURL
			CGPDFDocumentRef thePDFDocRef = CGPDFDocumentCreateX(docURLRef, _password);
			if (thePDFDocRef != NULL) {										// Get the number of pages in a document
				NSInteger pageCount = CGPDFDocumentGetNumberOfPages(thePDFDocRef);
				_pageCount = [NSNumber numberWithInteger:pageCount];
				CGPDFDocumentRelease(thePDFDocRef); // Cleanup
			}
			else {															// Cupertino, we have a problem with the document
				NSAssert(NO, @"CGPDFDocumentRef == NULL");
			}
			
			self.lastOpen = [NSDate dateWithTimeIntervalSinceReferenceDate:0.0];
			
			NSFileManager *fileManager = [NSFileManager new];
			NSDictionary *fileAttributes = [fileManager attributesOfItemAtPath:fullFilePath error:NULL];
			self.fileDate = [fileAttributes objectForKey:NSFileModificationDate]; // File date
			self.fileSize = [fileAttributes objectForKey:NSFileSize];		// File size (bytes)
			
			[self saveReaderDocument];
			object = self;
		}
	}

	return object;
}

- (NSString *)fileName
{
	return [_fileName lastPathComponent];
}

- (NSURL *)fileURL
{
	if (!_fileURL) {
		NSString *fullFilePath = [[ReaderDocument applicationPath] stringByAppendingPathComponent:_fileName];
		self.fileURL = [[NSURL alloc] initFileURLWithPath:fullFilePath isDirectory:NO]; // File URL from full file path
	}

	return _fileURL;
}


#pragma mark - Archiving/NSCoding
- (BOOL)archiveWithFileName:(NSString *)filename
{
	NSString *archiveFilePath = [ReaderDocument archiveFilePath:filename];
	return [NSKeyedArchiver archiveRootObject:self toFile:archiveFilePath];
}

- (void)saveReaderDocument
{
	[self archiveWithFileName:[self fileName]];
}

- (void)updateProperties
{
}


- (void)encodeWithCoder:(NSCoder *)encoder
{
	[encoder encodeObject:_guid forKey:@"FileGUID"];
	[encoder encodeObject:_fileName forKey:@"FileName"];
	[encoder encodeObject:_fileDate forKey:@"FileDate"];
	[encoder encodeObject:_pageCount forKey:@"PageCount"];
	[encoder encodeObject:_pageNumber forKey:@"PageNumber"];
	[encoder encodeObject:_bookmarks forKey:@"Bookmarks"];
	[encoder encodeObject:_fileSize forKey:@"FileSize"];
	[encoder encodeObject:_lastOpen forKey:@"LastOpen"];
}

- (id)initWithCoder:(NSCoder *)decoder
{
	if ((self = [super init])) {
		self.guid = [decoder decodeObjectForKey:@"FileGUID"];
		self.fileName = [decoder decodeObjectForKey:@"FileName"];
		self.fileDate = [decoder decodeObjectForKey:@"FileDate"];
		self.pageCount = [decoder decodeObjectForKey:@"PageCount"];
		self.pageNumber = [decoder decodeObjectForKey:@"PageNumber"];
		self.bookmarks = [[decoder decodeObjectForKey:@"Bookmarks"] mutableCopy];
		self.fileSize = [decoder decodeObjectForKey:@"FileSize"];
		self.lastOpen = [decoder decodeObjectForKey:@"LastOpen"];
		
		if (!_bookmarks) {
			self.bookmarks = [NSMutableIndexSet new];
		}
		if (!_guid) {
			self.guid = [ReaderDocument GUID];
		}
	}
	
	return self;
}


@end
