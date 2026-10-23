// HUDMetrics.m
#import "HUDMetrics.h"
#import <QuartzCore/QuartzCore.h>
#import <mach/mach.h>
#import <mach/mach_host.h>
#import <sys/sysctl.h>

@interface HUDMetrics ()
@property (nonatomic, strong) CADisplayLink *displayLink;
@property (nonatomic) NSTimeInterval lastTimestamp;
@property (nonatomic) NSInteger frameCount;
@property (nonatomic) double fps;
@property (nonatomic) double memoryMB;
@property (nonatomic) double cpuPercent;

// CPU usage tracking
@property (nonatomic) NSTimeInterval lastCPUTime;
@property (nonatomic) integer_t lastCPUUser;
@property (nonatomic) integer_t lastCPUSystem;
@property (nonatomic) integer_t lastCPUIdle;
@end

@implementation HUDMetrics

+ (instancetype)sharedMetrics {
    static HUDMetrics *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[HUDMetrics alloc] init];
    });
    return shared;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _fps = 0;
        _memoryMB = 0;
        _cpuPercent = 0;
        _lastTimestamp = 0;
        _frameCount = 0;
    }
    return self;
}

- (void)start {
    if (self.displayLink) return;

    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(tick:)];
    [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];

    // Sample CPU/memory every second on a separate timer.
    [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(sampleSystemMetrics) userInfo:nil repeats:YES];
}

- (void)stop {
    [self.displayLink invalidate];
    self.displayLink = nil;
}

- (void)tick:(CADisplayLink *)link {
    if (self.lastTimestamp == 0) {
        self.lastTimestamp = link.timestamp;
        return;
    }

    self.frameCount++;
    NSTimeInterval elapsed = link.timestamp - self.lastTimestamp;
    if (elapsed >= 1.0) {
        self.fps = self.frameCount / elapsed;
        self.frameCount = 0;
        self.lastTimestamp = link.timestamp;
    }
}

- (void)sampleSystemMetrics {
    // Memory
    task_vm_info_data_t vmInfo;
    mach_msg_type_number_t count = TASK_VM_INFO_COUNT;
    kern_return_t kr = task_info(mach_task_self(), TASK_VM_INFO, (task_info_t)&vmInfo, &count);
    if (kr == KERN_SUCCESS) {
        self.memoryMB = (double)vmInfo.phys_footprint / (1024.0 * 1024.0);
    }

    // CPU
    mach_msg_type_number_t cpuCount = HOST_CPU_LOAD_INFO_COUNT;
    host_cpu_load_info_data_t cpuInfo;
    kr = host_statistics64(mach_host_self(), HOST_CPU_LOAD_INFO, (host_info64_t)&cpuInfo, &cpuCount);
    if (kr == KERN_SUCCESS) {
        integer_t user = cpuInfo.cpu_ticks[CPU_STATE_USER];
        integer_t system = cpuInfo.cpu_ticks[CPU_STATE_SYSTEM];
        integer_t idle = cpuInfo.cpu_ticks[CPU_STATE_IDLE];
        integer_t nice = cpuInfo.cpu_ticks[CPU_STATE_NICE];

        if (self.lastCPUTime != 0) {
            integer_t totalDiff = (user + system + idle + nice) - (self.lastCPUUser + self.lastCPUSystem + self.lastCPUIdle);
            integer_t usedDiff = (user + system) - (self.lastCPUUser + self.lastCPUSystem);
            if (totalDiff > 0) {
                self.cpuPercent = (double)usedDiff / (double)totalDiff * 100.0;
            }
        }

        self.lastCPUUser = user;
        self.lastCPUSystem = system;
        self.lastCPUIdle = idle;
        self.lastCPUTime = [NSDate timeIntervalSinceReferenceDate];
    }
}

@end
