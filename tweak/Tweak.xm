// Tweak.xm – CAPerfHUDOverlay
// Injects into SpringBoard (HUD overlay window) and backboardd (frame counter
// for the real panel refresh rate). The two modes never mix: backboardd has
// no UIKit, so the frame-counter branch must return before anything UIKit
// related runs.

#import <UIKit/UIKit.h>
#import "HUDOverlayWindow.h"
#import "HUDFrameCounter.h"

static HUDOverlayWindow *overlayWindow = nil;

%ctor {
    NSString *procName = [NSString stringWithUTF8String:getprogname()];
    if ([procName isEqualToString:@"backboardd"]) {
        // Frame-counter mode: count render-server commits and share them with
        // SpringBoard through a small mmap file. No UIKit, no UI.
        CAPerfFrameCounterStart();
        return;
    }

    // SpringBoard tweak entry point.
    // Defer to the next runloop tick so SpringBoard is fully ready.
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!overlayWindow) {
            // The window starts hidden and only becomes visible (and touchable)
            // when the custom overlay is enabled from the app. It never becomes
            // the key window, so SpringBoard input is never disturbed.
            overlayWindow = [[HUDOverlayWindow alloc] init];
        }
    });
}
