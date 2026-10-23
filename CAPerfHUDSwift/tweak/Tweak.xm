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
            overlayWindow = [[HUDOverlayWindow alloc] init];
            [overlayWindow makeKeyAndVisible];
        }
    });
}
