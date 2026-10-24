// HUDMetrics.h
#import <Foundation/Foundation.h>

@interface HUDMetrics : NSObject

+ (instancetype)sharedMetrics;

// Start periodic collection.
- (void)start;
- (void)stop;

// Latest values (updated ~ every second).
@property (nonatomic, readonly) double fps;
@property (nonatomic, readonly) double memoryMB;
@property (nonatomic, readonly) double memoryTotalMB;
@property (nonatomic, readonly) double cpuPercent;

// Device-wide battery/power metrics (°C, W, KB/s, 0-100; negative = unknown).
@property (nonatomic, readonly) double temperatureC;
@property (nonatomic, readonly) double powerWatts;

// FPS diagnostics: the displayed value and where it came from. Inside
// SpringBoard a CADisplayLink is pinned to the 60 Hz UI vsync, so the honest
// value is the panel refresh rate read from the display driver (IORegistry);
// the display-link measurement is only a fallback.
@property (nonatomic, readonly) double measuredFPS;            // CADisplayLink rate (may be clamped)
@property (nonatomic, readonly) double panelRefreshRate;       // display driver rate, 0 = unavailable
@property (nonatomic, readonly) BOOL hasPanelRefreshRate;
@property (nonatomic, readonly, copy) NSString *panelScanSummary;
@property (nonatomic, readonly) double netDownKBps;
@property (nonatomic, readonly) double netUpKBps;
@property (nonatomic, readonly) double batteryPercent;

@end
