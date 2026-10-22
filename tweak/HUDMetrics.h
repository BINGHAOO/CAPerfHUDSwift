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
@property (nonatomic, readonly) double cpuPercent;

@end
