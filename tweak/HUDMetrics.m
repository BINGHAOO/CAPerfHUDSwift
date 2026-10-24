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

// IOKit functions are resolved at runtime with dlsym so the tweak does not
// need to link IOKit at build time. Battery data comes from the IORegistry
// (AppleSmartBattery / IOPMPowerSource), the classic and most reliable
// source on jailbroken iOS.
typedef uint32_t io_service_t_c;
typedef CFMutableDictionaryRef (*IOServiceMatchingFn)(const char *name);
typedef io_service_t_c (*IOServiceGetMatchingServiceFn)(mach_port_t masterPort, CFDictionaryRef matching);
typedef kern_return_t (*IORegistryEntryCreateCFPropertiesFn)(uint32_t entry, CFMutableDictionaryRef *properties, CFAllocatorRef allocator, UInt32 options);
typedef kern_return_t (*IOObjectReleaseFn)(uint32_t object);

static IOServiceMatchingFn gServiceMatching = NULL;
static IOServiceGetMatchingServiceFn gGetService = NULL;
static IORegistryEntryCreateCFPropertiesFn gCreateProps = NULL;
static IOObjectReleaseFn gObjectRelease = NULL;

static void EnsureIOKitSymbols(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        void *handle = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_LAZY);
        if (!handle) return;
        gServiceMatching = (IOServiceMatchingFn)dlsym(handle, "IOServiceMatching");
        gGetService = (IOServiceGetMatchingServiceFn)dlsym(handle, "IOServiceGetMatchingService");
        gCreateProps = (IORegistryEntryCreateCFPropertiesFn)dlsym(handle, "IORegistryEntryCreateCFProperties");
        gObjectRelease = (IOObjectReleaseFn)dlsym(handle, "IOObjectRelease");
    });
}

// Fills outProps with the property table of the first IORegistry node of the
// given class. Returns NO when the class is absent or IOKit is unavailable.
// On YES the caller must CFRelease(*outProps) and gObjectRelease(*outService).
static BOOL CopyFirstServiceProperties(NSString *cls, CFMutableDictionaryRef *outProps, io_service_t_c *outService) {
    if (!gServiceMatching || !gGetService || !gCreateProps || !gObjectRelease) return NO;
    CFMutableDictionaryRef matching = gServiceMatching(cls.UTF8String);
    if (!matching) return NO;
    // IOServiceGetMatchingService consumes one reference to matching.
    io_service_t_c service = gGetService(0, matching); // 0 = kIOMasterPortDefault
    if (!service) return NO;

    CFMutableDictionaryRef props = NULL;
    if (gCreateProps(service, &props, kCFAllocatorDefault, 0) != KERN_SUCCESS || !props) {
        gObjectRelease(service);
        return NO;
    }
    *outProps = props;
    *outService = service;
    return YES;
}

@interface HUDMetrics ()
@property (nonatomic, strong) CADisplayLink *displayLink;
@property (nonatomic, strong) NSTimer *systemTimer;
@property (nonatomic) NSTimeInterval lastTimestamp;
@property (nonatomic) NSInteger frameCount;
@property (nonatomic) double fps;
@property (nonatomic) double measuredFPS;    // CADisplayLink count (clamped to 60 in SpringBoard)
@property (nonatomic) double panelRefreshRate; // real panel Hz from the display driver
@property (nonatomic) BOOL hasPanelRefreshRate;
@property (nonatomic) double memoryMB;
@property (nonatomic) double memoryTotalMB;
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
        _memoryTotalMB = 0;
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
        // Request the full ProMotion band explicitly. Do NOT derive this from
        // UIScreen.maximumFramesPerSecond: in some SpringBoard environments it
        // reports 60, which would silently clamp the whole range back to 60.
        // On 60 Hz panels the system clamps the maximum automatically.
        CAFrameRateRange range = CAFrameRateRangeMake(60.0f, 120.0f, 120.0f);
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
    // Panel refresh rate first: on success it overrides the display-link
    // measurement for the FPS readout (see samplePanelRefreshRate).
    [self samplePanelRefreshRate];

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
        self.memoryTotalMB = (double)totalBytes / (1024.0 * 1024.0);

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

    // CADisplayLink inside SpringBoard is pinned to the 60 Hz UI vsync no
    // matter what the panel does. When the display driver reports the real
    // panel rate, that is the honest FPS value.
    if (self.hasPanelRefreshRate) {
        self.measuredFPS = self.fps;
        self.fps = self.panelRefreshRate;
    }
}

#pragma mark - Battery / temperature / power (IORegistry)

// Returns YES when at least one value was read from the property table.
- (BOOL)consumeBatteryProperties:(CFDictionaryRef)props {
    BOOL got = NO;

    // Battery temperature. The registry reports centi-degrees
    // (e.g. 3300 = 33 °C); an already-Celsius value passes through.
    CFNumberRef temp = CFDictionaryGetValue(props, CFSTR("Temperature"));
    if (temp) {
        double t = 0;
        if (CFNumberGetValue(temp, kCFNumberDoubleType, &t) && t > -100.0 && t < 10000.0) {
            if (t > 100.0) t /= 100.0;
            if (t > -20.0 && t < 100.0) {
                self.temperatureC = t;
                got = YES;
            }
        }
    }

    // Instantaneous battery power: Voltage [mV] × Amperage [mA].
    // InstantAmperage is preferred; Amperage is the same unit averaged.
    CFNumberRef voltage = CFDictionaryGetValue(props, CFSTR("Voltage"));
    CFNumberRef amperage = CFDictionaryGetValue(props, CFSTR("InstantAmperage"));
    if (!amperage) amperage = CFDictionaryGetValue(props, CFSTR("Amperage"));
    if (voltage && amperage) {
        double mv = 0, ma = 0;
        if (CFNumberGetValue(voltage, kCFNumberDoubleType, &mv) &&
            CFNumberGetValue(amperage, kCFNumberDoubleType, &ma) && mv > 0) {
            double watts = fabs(mv * ma) / 1000000.0;
            if (watts < 100) {
                self.powerWatts = watts;
                got = YES;
            }
        }
    }

    // Battery level (percent).
    CFNumberRef cap = CFDictionaryGetValue(props, CFSTR("CurrentCapacity"));
    if (cap) {
        double pct = 0;
        if (CFNumberGetValue(cap, kCFNumberDoubleType, &pct) && pct >= 0 && pct <= 100) {
            self.batteryPercent = pct;
            got = YES;
        }
    }

    return got;
}

- (void)samplePowerSource {
    EnsureIOKitSymbols();

    // AppleSmartBattery carries the richest table; the generic
    // IOPMPowerSource node is the fallback with the same keys.
    for (NSString *cls in @[@"AppleSmartBattery", @"IOPMPowerSource"]) {
        CFMutableDictionaryRef props = NULL;
        io_service_t_c service = 0;
        if (!CopyFirstServiceProperties(cls, &props, &service)) continue;

        BOOL got = [self consumeBatteryProperties:props];
        CFRelease(props);
        gObjectRelease(service);
        if (got) return;
    }

    // Fallback for the battery level only: UIDevice works in every process.
    if (self.batteryPercent < 0) {
        UIDevice *device = [UIDevice currentDevice];
        device.batteryMonitoringEnabled = YES;
        double level = device.batteryLevel; // 0.0 – 1.0, -1 when unavailable
        if (level >= 0) self.batteryPercent = level * 100.0;
    }
}

#pragma mark - Panel refresh rate (real value from the display driver)

// The honest source for the FPS row. CADisplayLink inside SpringBoard is
// pinned to the 60 Hz UI vsync regardless of what the panel does, so we read
// the refresh rate straight from the display driver's IORegistry node
// (AppleDisplay). On ProMotion devices this tracks the panel live: LTPO
// downshifts when idle, ~120 while scrolling.
- (void)samplePanelRefreshRate {
    EnsureIOKitSymbols();

    for (NSString *cls in @[@"AppleDisplay", @"IOMobileFramebufferShim"]) {
        CFMutableDictionaryRef props = NULL;
        io_service_t_c service = 0;
        if (!CopyFirstServiceProperties(cls, &props, &service)) continue;

        BOOL found = NO;
        CFIndex count = CFDictionaryGetCount(props);
        if (count > 0) {
            const void **keys = malloc(sizeof(void *) * count);
            const void **values = malloc(sizeof(void *) * count);
            // CFDictionaryGetKeysAndValues fills both arrays (void return).
            CFDictionaryGetKeysAndValues(props, keys, values);
            for (CFIndex i = 0; i < count; i++) {
                if (CFGetTypeID(keys[i]) != CFStringGetTypeID()) continue;
                NSString *key = (__bridge NSString *)keys[i];
                if (![key.lowercaseString containsString:@"refresh"]) continue;
                if (CFGetTypeID(values[i]) != CFNumberGetTypeID()) continue;

                double hz = 0;
                if (CFNumberGetValue((__bridge CFNumberRef)values[i], kCFNumberDoubleType, &hz) &&
                    hz >= 1.0 && hz <= 240.0) {
                    self.panelRefreshRate = hz;
                    self.hasPanelRefreshRate = YES;
                    found = YES;
                    break;
                }
            }
            free(keys);
            free(values);
        }
        CFRelease(props);
        gObjectRelease(service);
        if (found) return;
    }

    self.hasPanelRefreshRate = NO;
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
