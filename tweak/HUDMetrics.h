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
@property (nonatomic, readonly) double netDownKBps;
@property (nonatomic, readonly) double netUpKBps;
@property (nonatomic, readonly) double batteryPercent;

@end
