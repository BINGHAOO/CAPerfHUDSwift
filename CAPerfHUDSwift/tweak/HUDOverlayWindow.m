// HUDOverlayWindow.m
#import "HUDOverlayWindow.h"
#import "HUDOverlayView.h"
#import "HUDPreferences.h"

static void overlaySettingsChangedCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    HUDOverlayWindow *window = (__bridge HUDOverlayWindow *)observer;
    dispatch_async(dispatch_get_main_queue(), ^{
        window.notifyCount++;
        [window refreshFromPreferences];
    });
}

@implementation HUDOverlayWindow {
    HUDOverlayView *_overlayView;
}

@synthesize notifyCount = _notifyCount;

- (instancetype)init {
    self = [super initWithFrame:[UIScreen mainScreen].bounds];
    if (self) {
        // Sit above alerts, the status bar, and everything else.
        self.windowLevel = UIWindowLevelAlert + 1000;
        self.backgroundColor = [UIColor clearColor];

        _overlayView = [[HUDOverlayView alloc] init];
        [self addSubview:_overlayView];

        // Start hidden unless the custom overlay is enabled in the app.
        // NOTE: never call makeKeyAndVisible – taking key window status in
        // SpringBoard breaks touch routing for the whole system.
        [self refreshFromPreferences];

        // Follow settings changes from the app.
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                        (__bridge const void *)self,
                                        overlaySettingsChangedCallback,
                                        (__bridge CFStringRef)kCAPerfHUDSettingsChangedNotification,
                                        NULL,
                                        CFNotificationSuspensionBehaviorDeliverImmediately);
    }
    return self;
}

- (void)dealloc {
    CFNotificationCenterRemoveObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                       (__bridge const void *)self,
                                       (__bridge CFStringRef)kCAPerfHUDSettingsChangedNotification,
                                       NULL);
}

- (void)refreshFromPreferences {
    // Re-read the shared plist from disk – the singleton caches the plist
    // contents, so without an explicit reload here the tweak would forever
    // use the values from SpringBoard launch.
    [[HUDPreferences sharedPreferences] reload];

    BOOL enabled = [HUDPreferences sharedPreferences].enabled;
    BOOL shouldHide = !enabled;

    // Only flip the window visibility when the state actually changed –
    // repeated hidden toggles make SpringBoard re-composite its windows
    // (visible as a wallpaper flicker).
    if (self.hidden != shouldHide) {
        self.hidden = shouldHide;
        _overlayView.hidden = shouldHide;
    }

    if (enabled) {
        [_overlayView updateLayout];
        [_overlayView applyPreferences];
    }

    // Let the app see what the tweak actually loaded (see Diagnostics page).
    [[HUDPreferences sharedPreferences] writeDiagnosticsNotifyCount:self.notifyCount];
}

// Only let touches land on the overlay panel itself; everything else falls
// through to the windows underneath (SpringBoard pages, app UI, ...).
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    if (self.hidden || _overlayView.hidden) return nil;
    CGPoint local = [self convertPoint:point toView:_overlayView];
    return [_overlayView hitTest:local withEvent:event];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    if (!_overlayView.hidden) {
        [_overlayView updateLayout];
    }
}

@end
