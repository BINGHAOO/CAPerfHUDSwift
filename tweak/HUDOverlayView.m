// HUDOverlayView.m
// The actual cross-app HUD overlay. Reads shared prefs, collects metrics,
// and renders FPS / memory / CPU on a draggable window above everything.

#import "HUDOverlayView.h"
#import "HUDPreferences.h"
#import "HUDMetrics.h"

@implementation HUDOverlayView {
    UILabel *_label;
    UIPanGestureRecognizer *_pan;
    CGPoint _dragOffset;
    BOOL _hasSetInitialPosition;
    NSTimer *_refreshTimer;
}

- (instancetype)init {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        self.clipsToBounds = YES;
        self.userInteractionEnabled = YES;

        _label = [[UILabel alloc] init];
        _label.textAlignment = NSTextAlignmentCenter;
        _label.numberOfLines = 0;
        [self addSubview:_label];

        _pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        [self addGestureRecognizer:_pan];

        // Start hidden; visibility and metric collection follow the
        // "enabled" preference (applied by HUDOverlayWindow).
        self.hidden = YES;

        [self applyPreferences];
    }
    return self;
}

#pragma mark - Layout

- (void)updateLayout {
    if (_hasSetInitialPosition) return;

    HUDPreferences *prefs = [HUDPreferences sharedPreferences];
    CGFloat w = prefs.windowWidth;
    CGFloat h = prefs.windowHeight;

    // Default to top-center; the user can drag the panel anywhere.
    // (Manual X/Y offsets were removed – dragging covers it.)
    UIScreen *screen = [UIScreen mainScreen];
    CGFloat screenW = screen.bounds.size.width;
    CGFloat screenH = screen.bounds.size.height;

    CGFloat x = (screenW - w) / 2.0;
    CGFloat y = 60;

    // Clamp to screen.
    x = MAX(0, MIN(x, screenW - w));
    y = MAX(0, MIN(y, screenH - h));

    self.frame = CGRectMake(x, y, w, h);
    _label.frame = self.bounds;
    _hasSetInitialPosition = YES;
}

#pragma mark - Preferences

- (void)applyPreferences {
    HUDPreferences *prefs = [HUDPreferences sharedPreferences];

    // Show or hide based on the "enabled" flag written by the app.
    self.hidden = !prefs.enabled;

    // Start/stop metric collection together with the overlay so SpringBoard
    // does not burn CPU while the overlay is not in use.
    if (prefs.enabled) {
        if (_refreshTimer == nil) {
            _refreshTimer = [NSTimer timerWithTimeInterval:0.1 target:self selector:@selector(refreshText) userInfo:nil repeats:YES];
            [[NSRunLoop mainRunLoop] addTimer:_refreshTimer forMode:NSRunLoopCommonModes];
        }
        [[HUDMetrics sharedMetrics] start];
    } else {
        [_refreshTimer invalidate];
        _refreshTimer = nil;
        [[HUDMetrics sharedMetrics] stop];
    }

    // Resize
    CGRect frame = self.frame;
    frame.size.width = prefs.windowWidth;
    frame.size.height = prefs.windowHeight;
    self.frame = frame;
    _label.frame = self.bounds;

    // Background
    UIColor *bg = [self colorFromHex:prefs.bgColorHex];
    self.backgroundColor = [bg colorWithAlphaComponent:prefs.backgroundOpacity];

    // Corner radius
    self.layer.cornerRadius = prefs.cornerRadius;

    // Border
    if (prefs.showBorder) {
        self.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.3].CGColor;
        self.layer.borderWidth = prefs.borderWidth;
    } else {
        self.layer.borderWidth = 0;
    }

    // Text
    _label.font = [UIFont monospacedDigitSystemFontOfSize:prefs.fontSize weight:UIFontWeightMedium];
    _label.textColor = [self colorFromHex:prefs.textColorHex];
}

#pragma mark - Dragging

- (void)handlePan:(UIPanGestureRecognizer *)gesture {
    CGPoint location = [gesture locationInView:self.superview];

    switch (gesture.state) {
        case UIGestureRecognizerStateBegan: {
            CGPoint start = [gesture locationInView:self];
            _dragOffset = CGPointMake(start.x - self.frame.size.width / 2.0,
                                      start.y - self.frame.size.height / 2.0);
            break;
        }
        case UIGestureRecognizerStateChanged: {
            CGRect frame = self.frame;
            frame.origin.x = location.x - self.frame.size.width / 2.0 - _dragOffset.x;
            frame.origin.y = location.y - self.frame.size.height / 2.0 - _dragOffset.y;

            // Clamp to screen bounds.
            UIScreen *screen = [UIScreen mainScreen];
            CGFloat maxX = screen.bounds.size.width - frame.size.width;
            CGFloat maxY = screen.bounds.size.height - frame.size.height;
            frame.origin.x = MAX(0, MIN(frame.origin.x, maxX));
            frame.origin.y = MAX(0, MIN(frame.origin.y, maxY));

            self.frame = frame;
            break;
        }
        default:
            break;
    }
}

#pragma mark - Metrics text

// 3500 MB reads better as 3.42 GB on a narrow panel.
static NSString *FormattedMemory(double mb) {
    if (mb >= 1024.0) return [NSString stringWithFormat:@"%.2f GB", mb / 1024.0];
    return [NSString stringWithFormat:@"%.0f MB", mb];
}

static NSString *FormattedSpeed(double kbps) {
    if (kbps >= 1024.0) return [NSString stringWithFormat:@"%.1f MB/s", kbps / 1024.0];
    return [NSString stringWithFormat:@"%.0f KB/s", kbps];
}

- (void)refreshText {
    HUDMetrics *m = [HUDMetrics sharedMetrics];
    HUDPreferences *prefs = [HUDPreferences sharedPreferences];

    NSMutableArray<NSString *> *lines = [NSMutableArray array];
    if (prefs.showFPS) {
        [lines addObject:[NSString stringWithFormat:@"FPS  %.0f", m.fps]];
    }
    if (prefs.showCPU) {
        [lines addObject:[NSString stringWithFormat:@"CPU  %.0f%%", m.cpuPercent]];
    }
    if (prefs.showMemory) {
        [lines addObject:[NSString stringWithFormat:@"MEM  %@", FormattedMemory(m.memoryMB)]];
    }
    if (prefs.showTemperature) {
        if (m.temperatureC >= 0) {
            [lines addObject:[NSString stringWithFormat:@"TEMP %.1f°C", m.temperatureC]];
        } else {
            [lines addObject:@"TEMP N/A"];
        }
    }
    if (prefs.showPower) {
        if (m.powerWatts >= 0) {
            [lines addObject:[NSString stringWithFormat:@"PWR  %.2f W", m.powerWatts]];
        } else {
            [lines addObject:@"PWR  N/A"];
        }
    }
    if (prefs.showNetwork) {
        [lines addObject:[NSString stringWithFormat:@"NET  ↓%@ ↑%@", FormattedSpeed(m.netDownKBps), FormattedSpeed(m.netUpKBps)]];
    }
    if (prefs.showBattery) {
        if (m.batteryPercent >= 0) {
            [lines addObject:[NSString stringWithFormat:@"BAT  %.0f%%", m.batteryPercent]];
        } else {
            [lines addObject:@"BAT  N/A"];
        }
    }

    if (lines.count == 0) {
        [lines addObject:@"No metrics selected"];
    }
    _label.text = [lines componentsJoinedByString:@"\n"];
}

#pragma mark - Helpers

- (UIColor *)colorFromHex:(NSString *)hex {
    NSString *clean = [hex stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    clean = [clean stringByReplacingOccurrencesOfString:@"#" withString:@""];

    unsigned int rgb = 0;
    NSScanner *scanner = [NSScanner scannerWithString:clean];
    if (![scanner scanHexInt:&rgb]) return [UIColor whiteColor];

    CGFloat r, g, b, a = 1.0;
    if (clean.length == 6) {
        r = ((rgb >> 16) & 0xFF) / 255.0;
        g = ((rgb >> 8) & 0xFF) / 255.0;
        b = (rgb & 0xFF) / 255.0;
    } else if (clean.length == 8) {
        r = ((rgb >> 24) & 0xFF) / 255.0;
        g = ((rgb >> 16) & 0xFF) / 255.0;
        b = ((rgb >> 8) & 0xFF) / 255.0;
        a = (rgb & 0xFF) / 255.0;
    } else {
        return [UIColor whiteColor];
    }
    return [UIColor colorWithRed:r green:g blue:b alpha:a];
}

@end
