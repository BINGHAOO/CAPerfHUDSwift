// Tweak.xm – CAPerfHUDOverlay
// Injects into SpringBoard and creates a global, cross-app HUD overlay window.

#import <UIKit/UIKit.h>
#import "HUDOverlayWindow.h"

static HUDOverlayWindow *overlayWindow = nil;

%ctor {
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
