//
//	ReaderAppDelegate.m
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

#import "ReaderAppDelegate.h"

@implementation ReaderAppDelegate


#pragma mark - UIApplicationDelegate methods

- (BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url
{
	return NO;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
	mainWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];

//	[[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationNone];
	readerDemoController = [[ReaderDemoController alloc] initWithNibName:nil bundle:nil]; // Demo controller
	navigationController = [[UINavigationController alloc] initWithRootViewController:readerDemoController];
	mainWindow.backgroundColor = [UIColor scrollViewTexturedBackgroundColor]; // Window background color
	navigationController.navigationBar.barStyle = UIBarStyleBlack; navigationController.navigationBar.translucent = YES;
	mainWindow.rootViewController = navigationController; // Set the root view controller
	[mainWindow makeKeyAndVisible];
	
	return YES;
}

- (void)dealloc
{
	navigationController = nil;
	readerDemoController = nil;
	mainWindow = nil;
}


@end
