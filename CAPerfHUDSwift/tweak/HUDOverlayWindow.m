// HUDOverlayWindow.m
#import "HUDOverlayWindow.h"
#import "HUDOverlayView.h"
#import "HUDPreferences.h"

static void overlaySettingsChangedCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    HUDOverlayWindow *window = (__bridge HUDOverlayWindow *)observer;
    dispatch_async(dispatch_get_main_queue(), ^{
        [window refreshFromPreferences];
    });
}

@implementation HUDOverlayWindow {
    HUDOverlayView *_overlayView;
}

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
    BOOL enabled = [HUDPreferences sharedPreferences].enabled;

    // Hiding the whole window while disabled guarantees it cannot intercept
    // any touches (hidden windows never participate in hit testing).
    self.hidden = !enabled;
    _overlayView.hidden = !enabled;

    if (enabled) {
        [_overlayView updateLayout];
        [_overlayView applyPreferences];
    }
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
