// HUDOverlayWindow.h
#import <UIKit/UIKit.h>

@interface HUDOverlayWindow : UIWindow
// Reloads shared preferences and shows/hides the overlay accordingly.
- (void)refreshFromPreferences;
@end
