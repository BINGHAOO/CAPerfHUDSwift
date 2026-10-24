// HUDMetrics.m
#import "HUDMetrics.h"
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <mach/mach.h>
#import <mach/mach_host.h>
#import <sys/sysctl.h>
#import <dlfcn.h>
#import <ifaddrs.h>
#import <net/if.h>
#import <string.h>
#import <math.h>

// IOKit power source functions are resolved at runtime with dlsym so the
// tweak does not need to link IOKit at build time.
typedef CFTypeRef (*IOPSCopyPowerSourcesInfoFn)(void);
typedef CFArrayRef (*IOPSCopyPowerSourcesListFn)(CFTypeRef blob);
typedef CFDictionaryRef (*IOPSGetPowerSourceDescriptionFn)(CFTypeRef blob, CFTypeRef source);

@interface HUDMetrics ()
@property (nonatomic, strong) CADisplayLink *displayLink;
@property (nonatomic, strong) NSTimer *systemTimer;
@property (nonatomic) NSTimeInterval lastTimestamp;
@property (nonatomic) NSInteger frameCount;
@property (nonatomic) double fps;
@property (nonatomic) double memoryMB;
@property (nonatomic) double cpuPercent;
@property (nonatomic) double temperatureC;   // °C, <0 = unknown
@property (nonatomic) double powerWatts;     // W,  <0 = unknown
@property (nonatomic) double netDownKBps;
@property (nonatomic) double netUpKBps;
@property (nonatomic) double batteryPercent; // 0-100, <0 = unknown

// CPU usage tracking
@property (nonatomic) NSTimeInterval lastCPUTime;
@property (nonatomic) integer_t lastCPUUser;
@property (nonatomic) integer_t lastCPUSystem;
@property (nonatomic) integer_t lastCPUIdle;
@property (nonatomic) integer_t lastCPUNice;

// Network throughput tracking
@property (nonatomic) uint64_t lastNetInBytes;
@property (nonatomic) uint64_t lastNetOutBytes;
@property (nonatomic) BOOL hasNetBaseline;
@property (nonatomic) NSTimeInterval lastNetTimestamp;
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
        _temperatureC = -1;
        _powerWatts = -1;
        _netDownKBps = 0;
        _netUpKBps = 0;
        _batteryPercent = -1;
    }
    return self;
}

- (void)start {
    if (self.displayLink) return;

    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(tick:)];
    CGFloat maxFPS = [UIScreen mainScreen].maximumFramesPerSecond;
    if (@available(iOS 15.0, *)) {
        // On iOS 15+ ProMotion devices, setting preferredFramesPerSecond alone
        // does NOT unlock the 120 Hz panel – CADisplayLink stays pinned at
        // 60 Hz unless an explicit frame rate range is requested. The minimum
        // stays low so the link keeps following the LTPO panel when it
        // downshifts on static content.
        CAFrameRateRange range = CAFrameRateRangeMake(1, maxFPS, maxFPS);
        self.displayLink.preferredFrameRateRange = range;
    } else {
        self.displayLink.preferredFramesPerSecond = maxFPS;
    }
    [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];

    // Sample CPU/memory/battery/network every second on a separate timer.
    self.systemTimer = [NSTimer timerWithTimeInterval:1.0 target:self selector:@selector(sampleSystemMetrics) userInfo:nil repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:self.systemTimer forMode:NSRunLoopCommonModes];

    // Prime the baselines so the first second already shows values.
    [self sampleSystemMetrics];
}

- (void)stop {
    [self.displayLink invalidate];
    self.displayLink = nil;
    [self.systemTimer invalidate];
    self.systemTimer = nil;
    self.hasNetBaseline = NO;
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
    // Memory – global used RAM of the whole device, not this process:
    // wired + active + compressor pages (the standard "used" approximation).
    mach_msg_type_number_t vmCount = HOST_VM_INFO64_COUNT;
    vm_statistics64_data_t vmStat;
    if (host_statistics64(mach_host_self(), HOST_VM_INFO64, (host_info64_t)&vmStat, &vmCount) == KERN_SUCCESS) {
        vm_size_t pageSize = 0;
        if (host_page_size(mach_host_self(), &pageSize) != KERN_SUCCESS || pageSize == 0) {
            pageSize = 16384;
        }

        int64_t totalBytes = 0;
        size_t sz = sizeof(totalBytes);
        sysctlbyname("hw.memsize", &totalBytes, &sz, NULL, 0);
        if (totalBytes <= 0) {
            totalBytes = (int64_t)(vmStat.free_count + vmStat.active_count + vmStat.inactive_count +
                                   vmStat.wire_count + vmStat.purgeable_count + vmStat.compressor_page_count) * (int64_t)pageSize;
        }

        int64_t usedBytes = (int64_t)(vmStat.wire_count + vmStat.active_count + vmStat.compressor_page_count) * (int64_t)pageSize;
        if (usedBytes > totalBytes) usedBytes = totalBytes;
        if (usedBytes < 0) usedBytes = 0;
        self.memoryMB = (double)usedBytes / (1024.0 * 1024.0);
    }

    // CPU – global usage across all cores.
    mach_msg_type_number_t cpuCount = HOST_CPU_LOAD_INFO_COUNT;
    host_cpu_load_info_data_t cpuInfo;
    if (host_statistics64(mach_host_self(), HOST_CPU_LOAD_INFO, (host_info64_t)&cpuInfo, &cpuCount) == KERN_SUCCESS) {
        integer_t user = cpuInfo.cpu_ticks[CPU_STATE_USER];
        integer_t system = cpuInfo.cpu_ticks[CPU_STATE_SYSTEM];
        integer_t idle = cpuInfo.cpu_ticks[CPU_STATE_IDLE];
        integer_t nice = cpuInfo.cpu_ticks[CPU_STATE_NICE];

        if (self.lastCPUTime != 0) {
            integer_t totalDiff = (user + system + idle + nice) - (self.lastCPUUser + self.lastCPUSystem + self.lastCPUIdle + self.lastCPUNice);
            integer_t usedDiff = (user + system) - (self.lastCPUUser + self.lastCPUSystem);
            if (totalDiff > 0) {
                self.cpuPercent = (double)usedDiff / (double)totalDiff * 100.0;
            }
        }

        self.lastCPUUser = user;
        self.lastCPUSystem = system;
        self.lastCPUIdle = idle;
        self.lastCPUNice = nice;
        self.lastCPUTime = [NSDate timeIntervalSinceReferenceDate];
    }

    [self samplePowerSource];
    [self sampleNetwork];
}

#pragma mark - Battery / temperature / power (IOKit power sources)

- (void)samplePowerSource {
    static IOPSCopyPowerSourcesInfoFn copyInfo = NULL;
    static IOPSCopyPowerSourcesListFn copyList = NULL;
    static IOPSGetPowerSourceDescriptionFn getDescription = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        void *handle = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_LAZY);
        if (!handle) return;
        copyInfo = (IOPSCopyPowerSourcesInfoFn)dlsym(handle, "IOPSCopyPowerSourcesInfo");
        copyList = (IOPSCopyPowerSourcesListFn)dlsym(handle, "IOPSCopyPowerSourcesList");
        getDescription = (IOPSGetPowerSourceDescriptionFn)dlsym(handle, "IOPSGetPowerSourceDescription");
    });

    BOOL found = NO;
    if (copyInfo && copyList && getDescription) {
        CFTypeRef blob = copyInfo();
        if (blob) {
            CFArrayRef list = copyList(blob);
            if (list) {
                if (CFArrayGetCount(list) > 0) {
                    CFDictionaryRef desc = getDescription(blob, CFArrayGetValueAtIndex(list, 0));
                    if (desc) {
                        // Battery level (percent).
                        CFNumberRef current = CFDictionaryGetValue(desc, CFSTR("Current Capacity"));
                        if (current) {
                            double pct = 0;
                            if (CFNumberGetValue(current, kCFNumberDoubleType, &pct) && pct >= 0 && pct <= 100) {
                                self.batteryPercent = pct;
                                found = YES;
                            }
                        }

                        // Battery temperature. iOS reports centi-degrees
                        // (e.g. 3300 = 33 °C); an already-Celsius value
                        // passes through the normalisation untouched.
                        CFNumberRef temp = CFDictionaryGetValue(desc, CFSTR("Temperature"));
                        if (temp) {
                            double t = 0;
                            if (CFNumberGetValue(temp, kCFNumberDoubleType, &t) && t > -100.0 && t < 10000.0) {
                                if (t > 100.0) t /= 100.0;
                                if (t > -20.0 && t < 100.0) {
                                    self.temperatureC = t;
                                    found = YES;
                                }
                            }
                        }

                        // Instantaneous battery power: Voltage [mV] × Amperage [mA].
                        CFNumberRef voltage = CFDictionaryGetValue(desc, CFSTR("Voltage"));
                        CFNumberRef amperage = CFDictionaryGetValue(desc, CFSTR("Amperage"));
                        if (voltage && amperage) {
                            double mv = 0, ma = 0;
                            if (CFNumberGetValue(voltage, kCFNumberDoubleType, &mv) &&
                                CFNumberGetValue(amperage, kCFNumberDoubleType, &ma) && mv > 0) {
                                double watts = fabs(mv * ma) / 1000000.0;
                                if (watts < 100) {
                                    self.powerWatts = watts;
                                    found = YES;
                                }
                            }
                        }
                    }
                }
                CFRelease(list);
            }
            CFRelease(blob);
        }
    }

    // Fallback for the battery level only: UIDevice works in every process.
    if (!found && self.batteryPercent < 0) {
        UIDevice *device = [UIDevice currentDevice];
        device.batteryMonitoringEnabled = YES;
        double level = device.batteryLevel; // 0.0 – 1.0, -1 when unavailable
        if (level >= 0) self.batteryPercent = level * 100.0;
    }
}

#pragma mark - Network throughput (all interfaces, loopback excluded)

- (void)sampleNetwork {
    struct ifaddrs *addrs = NULL;
    if (getifaddrs(&addrs) != 0 || addrs == NULL) return;

    uint64_t inBytes = 0, outBytes = 0;
    for (struct ifaddrs *ifa = addrs; ifa != NULL; ifa = ifa->ifa_next) {
        if (!ifa->ifa_name || !ifa->ifa_addr) continue;
        // Per-interface byte counters live on the AF_LINK entries; one entry
        // per interface, so no double counting across AF_INET/AF_INET6.
        if (ifa->ifa_addr->sa_family != AF_LINK) continue;
        if (strcmp(ifa->ifa_name, "lo0") == 0) continue;
        struct if_data *data = (struct if_data *)ifa->ifa_data;
        if (!data) continue;
        inBytes += data->ifi_ibytes;
        outBytes += data->ifi_obytes;
    }
    freeifaddrs(addrs);

    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    if (self.hasNetBaseline && now > self.lastNetTimestamp) {
        NSTimeInterval elapsed = now - self.lastNetTimestamp;
        double down = ((double)inBytes - (double)self.lastNetInBytes) / elapsed / 1024.0;
        double up = ((double)outBytes - (double)self.lastNetOutBytes) / elapsed / 1024.0;
        // Counter resets (interface reload, VPN toggle) must not show up as
        // negative or absurd spikes.
        self.netDownKBps = down > 0 ? down : 0;
        self.netUpKBps = up > 0 ? up : 0;
    }
    self.lastNetInBytes = inBytes;
    self.lastNetOutBytes = outBytes;
    self.lastNetTimestamp = now;
    self.hasNetBaseline = YES;
}

@end
