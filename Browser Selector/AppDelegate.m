//
//  AppDelegate.m
//  Browser Selector
//
//  Created by Nick Dowell on 2014-04-14.
//  Copyright (c) 2014 Nick Dowell. All rights reserved.
//

#import "AppDelegate.h"


@interface AppInfo : NSObject
@property (copy, nonatomic) NSString *bundleIdentifier;
@property (copy, nonatomic) NSString *name;
@property (strong, nonatomic) NSImage *icon;
@end


@implementation AppInfo
@end


@interface AppDelegate ()

@property (strong, nonatomic) NSArray *apps;
@property (weak, nonatomic) AppInfo *currentApp;
@property (strong, nonatomic) NSStatusItem *statusItem;
@property (strong, nonatomic) NSMenu *menu;
@property (assign, nonatomic) BOOL autoSwitch;

@end


@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    self.autoSwitch = [[NSUserDefaults standardUserDefaults] boolForKey:@"AutoSwitch"];
    
    // these are not real browsers, but are hadlers for the http url scheme...
    NSArray *blacklist = @[@"ch.sudo.cyberduck",
                           @"com.evernote.evernote",
                           @"org.videolan.vlc",
                           @"com.blackpixel.versions",
                           ];
    
    self.apps = ({
        NSArray *array = @[];
        NSString *defaultHandler = CFBridgingRelease(LSCopyDefaultHandlerForURLScheme(CFSTR("http")));
        for (NSString *bundleIdentifier in CFBridgingRelease(LSCopyAllHandlersForURLScheme(CFSTR("http")))) {
            if ([blacklist containsObject:[bundleIdentifier lowercaseString]]) {
                continue;
            }
            CFURLRef applicationURL = NULL;
            CFStringRef applicationDisplayName = NULL;
            LSFindApplicationForInfo(kLSUnknownCreator, (__bridge CFStringRef)(bundleIdentifier), NULL, NULL, &applicationURL);
            LSCopyDisplayNameForURL(applicationURL, &applicationDisplayName);
            
            AppInfo *info = [[AppInfo alloc] init];
            info.bundleIdentifier = bundleIdentifier;
            info.name = CFBridgingRelease(applicationDisplayName);
            info.icon = ({
                NSImage *image = [[NSWorkspace sharedWorkspace] iconForFile:[(__bridge NSURL *)applicationURL path]];
                [image setScalesWhenResized:YES];
                [image setSize:NSMakeSize(18, 18)];
                image;
            });
            array = [array arrayByAddingObject:info];
            
            CFRelease(applicationURL);

            if ([bundleIdentifier isEqualToString:defaultHandler]) {
                self.currentApp = info;
            }
        }
        [array sortedArrayUsingSelector:@selector(name)];
    });
    
	self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength];
	[self.statusItem setHighlightMode:YES];
	[self.statusItem setMenu:({
        self.menu = [[NSMenu alloc] init];
        for (AppInfo *info in self.apps) {
            [self.menu addItem:({
                NSMenuItem *menuItem = [[NSMenuItem alloc] initWithTitle:info.name action:@selector(menuAction:) keyEquivalent:@""];
                if (info == self.currentApp) {
                    [menuItem setState:NSOnState];
                    [self.statusItem setImage:info.icon];
                }
                [menuItem setImage:info.icon];
                menuItem;
            })];
        }
        [self.menu addItem:[NSMenuItem separatorItem]];
        [self.menu addItem:({
            NSMenuItem *menuItem = [[NSMenuItem alloc] initWithTitle:@"Switch automatically" action:@selector(menuAction:) keyEquivalent:@""];
            [menuItem setState:self.autoSwitch ? NSOnState : NSOffState];
            [menuItem setTag:'auto'];
            menuItem;
        })];
        self.menu;
    })];
    
    [[NSWorkspace sharedWorkspace] addObserver:self forKeyPath:NSStringFromSelector(@selector(frontmostApplication)) options:0 context:NULL];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    id value = [object valueForKey:keyPath];
    if ([keyPath isEqualToString:NSStringFromSelector(@selector(frontmostApplication))]) {
        if (!self.autoSwitch) {
            return;
        }
        NSString *bundleIdentifier = [value bundleIdentifier];
        NSArray *bundleIdentifiers = [self.apps valueForKeyPath:NSStringFromSelector(@selector(bundleIdentifier))];
        NSInteger appIndex = [bundleIdentifiers indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
            return (*stop = ([obj caseInsensitiveCompare:bundleIdentifier] == NSOrderedSame));
        }];
        if (appIndex != NSNotFound) {
            OSStatus status = LSSetDefaultHandlerForURLScheme(CFSTR("http"), (__bridge CFStringRef)(bundleIdentifier));
            NSParameterAssert(status == noErr);
            for (NSInteger i=0; i<[self.apps count]; i++) {
                [[self.menu itemAtIndex:i] setState:i == appIndex ? NSOnState : NSOffState];
            }
            AppInfo *info = [self.apps objectAtIndex:appIndex];
            [self.statusItem setImage:info.icon];
            self.currentApp = info;
        }
    }
}

- (void)menuAction:(id)sender
{
    NSInteger itemIndex = [[self.menu itemArray] indexOfObject:sender];
    if (itemIndex < [self.apps count]) {
        AppInfo *info = [self.apps objectAtIndex:itemIndex];
        OSStatus status = LSSetDefaultHandlerForURLScheme(CFSTR("http"), (__bridge CFStringRef)(info.bundleIdentifier));
        NSParameterAssert(status == noErr);
        for (NSInteger i=0; i<[self.apps count]; i++) {
            [[self.menu itemAtIndex:i] setState:i == itemIndex ? NSOnState : NSOffState];
        }
        [self.statusItem setImage:info.icon];
        self.currentApp = info;
        return;
    }

    if ([sender tag] == 'auto') {
        self.autoSwitch = !self.autoSwitch;
        [[NSUserDefaults standardUserDefaults] setBool:self.autoSwitch forKey:@"AutoSwitch"];
        [sender setState:self.autoSwitch ? NSOnState : NSOffState];
    }
}

@end
