// HUDOverlayView.m
// The actual cross-app HUD overlay. Reads shared prefs, collects metrics,
// and renders FPS / memory / CPU on a draggable window above everything.

#import "HUDOverlayView.h"
#import "HUDPreferences.h"
#import "HUDMetrics.h"
#import <QuartzCore/QuartzCore.h>

// Safe margins so left/right aligned text does not hug the border, and so
// the first/last line do not touch the top/bottom edges.
static const CGFloat kTextHPadding = 8.0;
static const CGFloat kTextVPadding = 6.0;

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
    [self layoutLabel];
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

    // Resize. With auto-fit enabled the panel size is driven by the text
    // (see updateAutoSize), so the preference size is applied as the
    // starting/minimum frame only.
    CGRect frame = self.frame;
    if (self.frame.size.width < prefs.windowWidth) frame.size.width = prefs.windowWidth;
    if (!prefs.autoHeight) frame.size.height = prefs.windowHeight;
    self.frame = frame;
    [self layoutLabel];

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

    // Text. A fully monospaced font (SF Mono) is required for the padded
    // tags to line up: monospacedDigitSystemFont only fixes digits, so the
    // colons of "FPS:" and "TEMP:" ended up at different x positions.
    _label.font = [UIFont monospacedSystemFontOfSize:prefs.fontSize weight:UIFontWeightMedium];
    _label.textColor = [self colorFromHex:prefs.textColorHex];
    _label.textAlignment = [self alignmentForIndex:prefs.textAlignment];

    // Keep the panel render-active: without any live Core Animation activity,
    // iOS clamps a CADisplayLink to the idle 60 Hz UI rate and the FPS readout
    // sticks at ~60 even when the panel is capable of more. The 0.1 % opacity
    // wiggle is invisible but keeps the layer on the render server's active
    // list, so the display link tracks the requested (up to 120 Hz) rate.
    if ([self.layer animationForKey:@"hudKeepAlive"] == nil) {
        CABasicAnimation *keepAlive = [CABasicAnimation animationWithKeyPath:@"opacity"];
        keepAlive.fromValue = @1.0;
        keepAlive.toValue = @0.999;
        keepAlive.duration = 0.5;
        keepAlive.autoreverses = YES;
        keepAlive.repeatCount = HUGE_VALF;
        keepAlive.removedOnCompletion = NO;
        [self.layer addAnimation:keepAlive forKey:@"hudKeepAlive"];
    }
}

- (NSTextAlignment)alignmentForIndex:(NSInteger)idx {
    switch (idx) {
        case 0:  return NSTextAlignmentLeft;
        case 2:  return NSTextAlignmentRight;
        default: return NSTextAlignmentCenter;
    }
}

- (void)layoutLabel {
    _label.frame = CGRectMake(kTextHPadding, kTextVPadding,
                              MAX(0, self.bounds.size.width - kTextHPadding * 2),
                              MAX(0, self.bounds.size.height - kTextVPadding * 2));
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

// Tags are padded to a common width so the colons (and values) line up in
// the monospaced font: "FPS:  120" / "TEMP: 33.5°C".
static NSString *PaddedTag(NSString *tag) {
    while (tag.length < 4) tag = [tag stringByAppendingString:@" "];
    return tag;
}

- (void)refreshText {
    HUDMetrics *m = [HUDMetrics sharedMetrics];
    HUDPreferences *prefs = [HUDPreferences sharedPreferences];

    NSMutableArray<NSString *> *lines = [NSMutableArray array];
    if (prefs.showFPS) {
        [lines addObject:[NSString stringWithFormat:@"%@:  %.0f", PaddedTag(@"FPS"), m.fps]];
    }
    if (prefs.showCPU) {
        [lines addObject:[NSString stringWithFormat:@"%@:  %.0f%%", PaddedTag(@"CPU"), m.cpuPercent]];
    }
    if (prefs.showMemory) {
        if (prefs.showMemoryPercent && m.memoryTotalMB > 0) {
            double pct = MIN(100.0, m.memoryMB / m.memoryTotalMB * 100.0);
            [lines addObject:[NSString stringWithFormat:@"%@:  %@ (%.0f%%)", PaddedTag(@"MEM"), FormattedMemory(m.memoryMB), pct]];
        } else {
            [lines addObject:[NSString stringWithFormat:@"%@:  %@", PaddedTag(@"MEM"), FormattedMemory(m.memoryMB)]];
        }
    }
    if (prefs.showTemperature) {
        if (m.temperatureC >= 0) {
            [lines addObject:[NSString stringWithFormat:@"%@:  %.1f°C", PaddedTag(@"TEMP"), m.temperatureC]];
        } else {
            [lines addObject:[NSString stringWithFormat:@"%@:  N/A", PaddedTag(@"TEMP")]];
        }
    }
    if (prefs.showPower) {
        if (m.powerWatts >= 0) {
            [lines addObject:[NSString stringWithFormat:@"%@:  %.2f W", PaddedTag(@"PWR"), m.powerWatts]];
        } else {
            [lines addObject:[NSString stringWithFormat:@"%@:  N/A", PaddedTag(@"PWR")]];
        }
    }
    if (prefs.showNetwork) {
        [lines addObject:[NSString stringWithFormat:@"%@:  ↓%@ ↑%@", PaddedTag(@"NET"), FormattedSpeed(m.netDownKBps), FormattedSpeed(m.netUpKBps)]];
    }
    if (prefs.showBattery) {
        if (m.batteryPercent >= 0) {
            [lines addObject:[NSString stringWithFormat:@"%@:  %.0f%%", PaddedTag(@"BAT"), m.batteryPercent]];
        } else {
            [lines addObject:[NSString stringWithFormat:@"%@:  N/A", PaddedTag(@"BAT")]];
        }
    }

    if (lines.count == 0) {
        [lines addObject:@"No metrics selected"];
    }
    _label.text = [lines componentsJoinedByString:@"\n"];

    [self updateAutoSize];
}

// Auto-fit size: grows the panel so nothing ever wraps. The width follows
// the longest line (network speeds can be very long), the height follows
// the line count. The top-left corner stays anchored where the user dragged
// it, and the user-set width acts as the minimum so small panels stay small.
- (void)updateAutoSize {
    HUDPreferences *prefs = [HUDPreferences sharedPreferences];
    if (!prefs.autoHeight) return;

    NSDictionary *attrs = @{NSFontAttributeName: _label.font};
    CGFloat textW = 0;
    for (NSString *line in [_label.text componentsSeparatedByString:@"\n"]) {
        CGFloat w = ceil([line sizeWithAttributes:attrs].width);
        if (w > textW) textW = w;
    }

    // Width: user-set minimum, grown to fit the longest line.
    CGFloat width = MAX(prefs.windowWidth, textW + kTextHPadding * 2);
    CGFloat maxW = [UIScreen mainScreen].bounds.size.width - self.frame.origin.x - 8;
    width = MIN(width, MAX(maxW, prefs.windowWidth));
    if (fabs(self.frame.size.width - width) > 0.5) {
        CGRect f = self.frame;
        f.size.width = width;
        self.frame = f;
    }
    [self layoutLabel];

    // Height: fit every line plus the top/bottom safe margins.
    CGSize fit = [_label sizeThatFits:CGSizeMake(MAX(0, self.bounds.size.width - kTextHPadding * 2), CGFLOAT_MAX)];
    CGFloat minHeight = _label.font.lineHeight + kTextVPadding * 2;
    CGFloat needed = MAX(fit.height, _label.font.lineHeight) + kTextVPadding * 2;

    // Never grow past the bottom of the screen.
    CGFloat maxH = [UIScreen mainScreen].bounds.size.height - self.frame.origin.y - 8;
    needed = MIN(needed, MAX(maxH, minHeight));

    if (fabs(self.frame.size.height - needed) > 0.5) {
        CGRect f = self.frame;
        f.size.height = needed;
        self.frame = f;
    }
    [self layoutLabel];
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
