// HUDOverlayWindow.h
#import <UIKit/UIKit.h>

@interface HUDOverlayWindow : UIWindow
// Reloads shared preferences and shows/hides the overlay accordingly.
- (void)refreshFromPreferences;
// Number of Darwin notifications received from the app (diagnostics).
@property (nonatomic, assign) NSInteger notifyCount;
@end
