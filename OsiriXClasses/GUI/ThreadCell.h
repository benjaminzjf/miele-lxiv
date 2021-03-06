//
//  ©Alex Bettarini -- all rights reserved
//  License GPLv3.0 -- see License File
//
//  At the end of 2014 the project was forked from OsiriX to become Miele-LXIV
//  The original header follows:
/*=========================================================================
 Program:   OsiriX
 
 Copyright (c) OsiriX Team
 All rights reserved.
 Distributed under GNU - LGPL
 
 See http://www.osirix-viewer.com/copyright.html for details.
 
 This software is distributed WITHOUT ANY WARRANTY; without even
 the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
 PURPOSE.
 =========================================================================*/

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

@class ThreadsManager;

@interface ThreadCell : NSTextFieldCell {
	NSProgressIndicator* _progressIndicator;
	ThreadsManager* _manager;
	NSButton* _cancelButton;
	NSThread* _thread;
    id _retainedThreadDictionary;
	NSTableView* _view;

    CGFloat _lastDisplayedProgress;
    BOOL KVOObserving;
}

@property(retain) NSProgressIndicator* progressIndicator;
@property(retain) NSButton* cancelButton;
@property(nonatomic, retain) NSThread* thread;
@property(assign, readonly) ThreadsManager* manager;
@property(assign, readonly) NSTableView* view;

-(id)initWithThread:(NSThread*)thread manager:(ThreadsManager*)manager view:(NSTableView*)view;

-(void)cleanup;

-(NSRect)statusFrame;

@end
