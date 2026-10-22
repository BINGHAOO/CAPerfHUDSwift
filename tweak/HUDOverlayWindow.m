// HUDOverlayWindow.m
#import "HUDOverlayWindow.h"
#import "HUDOverlayView.h"

@implementation HUDOverlayWindow {
    HUDOverlayView *_overlayView;
}

- (instancetype)init {
    self = [super initWithFrame:[UIScreen mainScreen].bounds];
    if (self) {
        // Sit above alerts, the status bar, and everything else.
        self.windowLevel = UIWindowLevelAlert + 1000;
        self.backgroundColor = [UIColor clearColor];
        self.rootViewController = [UIViewController new];
        self.userInteractionEnabled = YES;
        self.hidden = NO;

        _overlayView = [[HUDOverlayView alloc] init];
        [self addSubview:_overlayView];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [_overlayView updateLayout];
}

@end
