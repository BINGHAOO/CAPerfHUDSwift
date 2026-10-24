// HUDMetrics.m
#import "HUDMetrics.h"
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <mach/mach.h>
#import <mach/mach_host.h>
#import <sys/sysctl.h>
#import <dlfcn.h>
#import <fcntl.h>
#import <unistd.h>
#import <ifaddrs.h>
#import <net/if.h>
#import <string.h>
#import <math.h>

// IOKit functions are resolved at runtime with dlsym so the tweak does not
// need to link IOKit at build time. Battery data comes from the IORegistry
// (AppleSmartBattery / IOPMPowerSource), the classic and most reliable
// source on jailbroken iOS.
typedef uint32_t io_service_t_c;
typedef uint32_t io_iterator_t_c;
typedef CFMutableDictionaryRef (*IOServiceMatchingFn)(const char *name);
typedef io_service_t_c (*IOServiceGetMatchingServiceFn)(mach_port_t masterPort, CFDictionaryRef matching);
typedef kern_return_t (*IOServiceGetMatchingServicesFn)(mach_port_t masterPort, CFDictionaryRef matching, io_iterator_t_c *iterator);
typedef io_service_t_c (*IOIteratorNextFn)(io_iterator_t_c iterator);
typedef kern_return_t (*IORegistryEntryCreateCFPropertiesFn)(uint32_t entry, CFMutableDictionaryRef *properties, CFAllocatorRef allocator, UInt32 options);
typedef kern_return_t (*IOObjectReleaseFn)(uint32_t object);

static IOServiceMatchingFn gServiceMatching = NULL;
static IOServiceGetMatchingServiceFn gGetService = NULL;
static IOServiceGetMatchingServicesFn gGetMatchingServices = NULL;
static IOIteratorNextFn gIteratorNext = NULL;
static IORegistryEntryCreateCFPropertiesFn gCreateProps = NULL;
static IOObjectReleaseFn gObjectRelease = NULL;

static void EnsureIOKitSymbols(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        void *handle = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_LAZY);
        if (!handle) return;
        gServiceMatching = (IOServiceMatchingFn)dlsym(handle, "IOServiceMatching");
        gGetService = (IOServiceGetMatchingServiceFn)dlsym(handle, "IOServiceGetMatchingService");
        gGetMatchingServices = (IOServiceGetMatchingServicesFn)dlsym(handle, "IOServiceGetMatchingServices");
        gIteratorNext = (IOIteratorNextFn)dlsym(handle, "IOIteratorNext");
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
@property (nonatomic) double measuredFPS;      // CADisplayLink count (may be clamped to 60)
@property (nonatomic) double panelRefreshRate; // real panel Hz from the display driver
@property (nonatomic) BOOL hasPanelRefreshRate;
@property (nonatomic, copy) NSString *panelScanSummary;
@property (nonatomic) double backboarddFrameRate; // from the backboardd frame counter
@property (nonatomic) uint64_t lastBBFrameCount;
@property (nonatomic) uint64_t lastBBFrameTs;
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
        _panelScanSummary = @"not scanned yet";
    }
    return self;
}

// Dedicated thread for the FPS display link. In SpringBoard the main-runloop
// CADisplayLink is pinned to the 60 Hz UI vsync track no matter what
// preferredFrameRateRange requests (observed on iOS 15 ProMotion). A display
// link scheduled on its own thread's runloop registers as an independent
// vsync client and can track the panel rate – the standard approach used by
// iOS FPS overlay tools.
static NSThread *_fpsLoopThread = nil;

- (void)ensureFPSLoopThread {
    if (_fpsLoopThread && !_fpsLoopThread.finished) return;
    _fpsLoopThread = [[NSThread alloc] initWithTarget:self selector:@selector(fpsThreadMain) object:nil];
    _fpsLoopThread.name = @"CAPerfHUD-FPS";
    [_fpsLoopThread start];
}

- (void)fpsThreadMain {
    @autoreleasepool {
        // Keep the runloop alive forever; the display link is scheduled here.
        [[NSRunLoop currentRunLoop] addPort:[NSPort port] forMode:NSDefaultRunLoopMode];
        [[NSRunLoop currentRunLoop] run];
    }
}

- (void)createDisplayLinkOnThread {
    CADisplayLink *link = [CADisplayLink displayLinkWithTarget:self selector:@selector(tick:)];
    if (@available(iOS 15.0, *)) {
        // Ask for 120 Hz unconditionally. On 60 Hz panels the system clamps
        // the maximum automatically, so this is safe everywhere.
        CAFrameRateRange range = CAFrameRateRangeMake(120.0f, 120.0f, 120.0f);
        link.preferredFrameRateRange = range;
    } else {
        link.preferredFramesPerSecond = [UIScreen mainScreen].maximumFramesPerSecond;
    }
    [link addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    self.displayLink = link;
}

- (void)start {
    if (self.displayLink) return;

    [self ensureFPSLoopThread];
    [self performSelector:@selector(createDisplayLinkOnThread)
                  onThread:_fpsLoopThread
                withObject:nil
             waitUntilDone:NO
                    modes:@[ NSDefaultRunLoopMode ]];

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
        self.measuredFPS = self.fps;
        self.frameCount = 0;
        self.lastTimestamp = link.timestamp;
    }
}

#pragma mark - Backboardd frame counter (the real panel rate)

// Reads the frame counter the tweak instance inside backboardd publishes
// through a shared mmap file. The delta over one second is the frame rate
// the panel actually displayed, straight from the render server.
- (void)sampleBackboarddFrames {
    static const char *kSharedPath = "/var/mobile/Library/Preferences/.caperfhud.framerate";

    int fd = open(kSharedPath, O_RDONLY);
    if (fd < 0) {
        self.backboarddFrameRate = -1;
        return;
    }
    uint64_t buf[2] = {0, 0};
    BOOL ok = pread(fd, buf, sizeof(buf), 0) == sizeof(buf);
    close(fd);
    if (!ok || buf[1] == 0) {
        self.backboarddFrameRate = -1;
        return;
    }

    uint64_t count = buf[0];
    uint64_t sec = buf[1];
    if (self.lastBBFrameTs > 0 && sec > self.lastBBFrameTs) {
        double dt = (double)(sec - self.lastBBFrameTs);
        double hz = (double)(count - self.lastBBFrameCount) / dt;
        self.backboarddFrameRate = (hz >= 1.0 && hz <= 240.0) ? hz : -1;
    } else {
        // First sample or the counter is stale (counter side missing).
        self.backboarddFrameRate = -1;
    }
    self.lastBBFrameCount = count;
    self.lastBBFrameTs = sec;
}

- (void)sampleSystemMetrics {
    // Panel refresh rate first: on success it overrides the display-link
    // measurement for the FPS readout (see samplePanelRefreshRate).
    [self samplePanelRefreshRate];

    // The backboardd frame counter beats every other source: the delta of
    // render-server commits over one second IS the frame rate the panel
    // actually displayed (ProMotion 120 while scrolling, LTPO downshifts
    // when idle). IORegistry and CADisplayLink are only fallbacks.
    [self sampleBackboarddFrames];
    if (self.backboarddFrameRate > 0) {
        self.panelRefreshRate = self.backboarddFrameRate;
        self.hasPanelRefreshRate = YES;
        self.panelScanSummary = [NSString stringWithFormat:@"backboardd frame counter: %.1f Hz", self.backboarddFrameRate];
    }

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
// the refresh rate straight from the display driver's IORegistry nodes. All
// instances of every display-related class are scanned for a refresh/hz
// property; whatever is found is also recorded in panelScanSummary so the
// diagnostics page can show exactly what the driver exposes on this device.
// Parse the live panel refresh rate out of an IOMFB CFType description.
// "IOMFBDisplayRefresh" is a private CFType whose CFCopyDescription output is
// a plist-style dict of interval fields (probed on iOS 15: values like
// "displayMinRefreshIntervalMachTime = 200016" == 8.33ms == 120Hz at the
// 24MHz mach timebase). Only *current*-value keys are considered here; the
// min/max bound keys are deliberately excluded so the allowed range is never
// mistaken for the live rate.
- (double)panelRateFromDescriptionText:(NSString *)text machTickNs:(double)machTickNs {
    if (text.length == 0 || text.length > 4096) return -1;
    NSArray<NSString *> *keys = @[
        @"displayRefreshIntervalMachTime",
        @"displayCurrentRefreshIntervalMachTime",
        @"displayActiveRefreshIntervalMachTime",
        @"displayRefreshInterval",
        @"displayCurrentRefreshInterval",
        @"displayActiveRefreshInterval",
        @"displayRefreshRate",
        @"displayCurrentRefreshRate",
    ];
    for (NSString *key in keys) {
        NSString *pattern = [NSString stringWithFormat:@"%@\\s*=\\s*([0-9]+(?:\\.[0-9]+)?)\\b", key];
        NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:NULL];
        NSTextCheckingResult *m = [re firstMatchInString:text options:0 range:NSMakeRange(0, text.length)];
        if (!m || [m rangeAtIndex:1].location == NSNotFound) continue;
        double v = [[text substringWithRange:[m rangeAtIndex:1]] doubleValue];
        if (v <= 0) continue;
        if ([key containsString:@"Rate"]) return v; // direct Hz value
        // Interval: two plausible units – mach ticks or nanoseconds. Accept
        // whichever interpretation lands on a real panel rate step.
        if (machTickNs > 0) {
            double hz = 1e9 / (v * machTickNs);
            if (fabs(hz - round(hz)) < 0.15 && [self isPlausiblePanelRate:(uint32_t)round(hz)]) return hz;
        }
        double hzNs = 1e9 / v;
        if (fabs(hzNs - round(hzNs)) < 0.15 && [self isPlausiblePanelRate:(uint32_t)round(hzNs)]) return hzNs;
    }
    return -1;
}

- (void)samplePanelRefreshRate {
    EnsureIOKitSymbols();

    // Some firmware/OS builds expose the current panel rate via sysctl.
    // Cheap to probe, no side effects when the key is absent.
    static const char *rateNames[] = {
        "hw.panelrefreshrate", "hw.panel_refresh_rate",
        "hw.displayrefreshrate", "kern.displayrefreshrate"
    };
    for (size_t n = 0; n < sizeof(rateNames) / sizeof(rateNames[0]); n++) {
        int32_t v = 0;
        size_t sz = sizeof(v);
        if (sysctlbyname(rateNames[n], &v, &sz, NULL, 0) == 0 && v > 0 &&
            [self isPlausiblePanelRate:(uint32_t)v]) {
            self.panelRefreshRate = v;
            self.hasPanelRefreshRate = YES;
            self.panelScanSummary = [NSString stringWithFormat:@"sysctl:%s=%d", rateNames[n], v];
            return;
        }
    }

    NSMutableArray<NSString *> *summary = [NSMutableArray array];
    mach_timebase_info_data_t tbi = {1, 1};
    mach_timebase_info(&tbi);
    double machTickNs = (double)tbi.numer / (double)tbi.denom;
    double displayRefreshVal = -1; // "current panel rate" keys – highest trust
    double otherVal = -1;          // any other plausible rate key
    double limitVal = -1;          // limit/ceiling keys – last resort

    if (gServiceMatching && gGetMatchingServices && gIteratorNext && gCreateProps && gObjectRelease) {
        for (NSString *cls in @[@"AppleDisplay", @"IOMobileFramebuffer", @"IOMobileFramebufferShim"]) {
            CFMutableDictionaryRef matching = gServiceMatching(cls.UTF8String);
            if (!matching) continue;
            // IOServiceGetMatchingServices consumes one reference to matching.
            io_iterator_t_c iter = 0;
            if (gGetMatchingServices(0, matching, &iter) != KERN_SUCCESS || !iter) continue;

            int idx = 0;
            io_service_t_c service = 0;
            while ((service = gIteratorNext(iter)) != 0) {
                CFMutableDictionaryRef props = NULL;
                if (gCreateProps(service, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS && props) {
                    CFIndex count = CFDictionaryGetCount(props);
                    if (count > 0) {
                        const void **keys = malloc(sizeof(void *) * count);
                        const void **values = malloc(sizeof(void *) * count);
                        // CFDictionaryGetKeysAndValues fills both arrays (void return).
                        CFDictionaryGetKeysAndValues(props, keys, values);
                        for (CFIndex i = 0; i < count; i++) {
                            if (CFGetTypeID(keys[i]) != CFStringGetTypeID()) continue;
                            NSString *key = (__bridge NSString *)keys[i];
                            NSString *lower = key.lowercaseString;
                            BOOL looksLikeRate = [lower containsString:@"refresh"] ||
                                                 [lower containsString:@"hz"] ||
                                                 [lower containsString:@"framerate"];
                            if (!looksLikeRate) continue;

                            // IOMFB reports most of its state as packed
                            // binary structs (CFData), e.g. the probed
                            // "IOMFBDisplayRefresh" on iOS 15. A raw number
                            // (CFNumber/CFString) is used directly; for a
                            // blob the little-endian u32 words are scanned
                            // against the known panel rate steps so that
                            // struct lengths and flags never match. The hex
                            // dump lands in the diagnostics either way.
                            double parsed = -1;
                            if (CFGetTypeID(values[i]) == CFNumberGetTypeID()) {
                                double hz = 0;
                                if (CFNumberGetValue((CFNumberRef)values[i], kCFNumberDoubleType, &hz) &&
                                    hz >= 1.0 && hz <= 240.0) {
                                    parsed = hz;
                                    [summary addObject:[NSString stringWithFormat:@"%@[%d].%@=%.0f", cls, idx, key, hz]];
                                } else {
                                    [summary addObject:[NSString stringWithFormat:@"%@[%d].%@=<number out of range>", cls, idx, key]];
                                }
                            } else if (CFGetTypeID(values[i]) == CFStringGetTypeID()) {
                                NSString *s = (__bridge NSString *)values[i];
                                double hz = s.doubleValue;
                                if (hz >= 1.0 && hz <= 240.0) {
                                    parsed = hz;
                                    [summary addObject:[NSString stringWithFormat:@"%@[%d].%@=%@ (%.0f Hz)", cls, idx, key, s, hz]];
                                } else {
                                    [summary addObject:[NSString stringWithFormat:@"%@[%d].%@=<string \"%@\">", cls, idx, key, s]];
                                }
                            } else if (CFGetTypeID(values[i]) == CFDataGetTypeID()) {
                                CFDataRef data = (CFDataRef)values[i];
                                const UInt8 *bytes = CFDataGetBytePtr(data);
                                CFIndex len = CFDataGetLength(data);
                                NSMutableString *desc = [NSMutableString stringWithFormat:@"data[%ld B:", (long)len];
                                for (CFIndex b = 0; b < MIN((CFIndex)16, len); b++) {
                                    [desc appendFormat:@" %02x", bytes[b]];
                                }
                                [desc appendString:@" ]"];
                                for (CFIndex off = 0; off + 4 <= len && off < 32; off += 4) {
                                    uint32_t v = (uint32_t)bytes[off] |
                                                 ((uint32_t)bytes[off + 1] << 8) |
                                                 ((uint32_t)bytes[off + 2] << 16) |
                                                 ((uint32_t)bytes[off + 3] << 24);
                                    if ([self isPlausiblePanelRate:v]) {
                                        parsed = v;
                                        [desc appendFormat:@" u32@%ld=%u", (long)off, v];
                                        break;
                                    }
                                }
                                [summary addObject:[NSString stringWithFormat:@"%@[%d].%@=%@", cls, idx, key, desc]];
                            } else if (CFGetTypeID(values[i]) == CFBooleanGetTypeID()) {
                                Boolean bv = CFBooleanGetValue((CFBooleanRef)values[i]);
                                [summary addObject:[NSString stringWithFormat:@"%@[%d].%@=%@", cls, idx, key, bv ? @"true" : @"false"]];
                            } else {
                                // Unknown/private CFType (IOMFB uses custom
                                // types – probed "IOMFBDisplayRefresh" shows
                                // up as a bare typeID whose description is a
                                // plist-style dict of interval fields). Dump
                                // the description and parse the live refresh
                                // interval straight out of it.
                                CFStringRef desc = CFCopyDescription(values[i]);
                                NSString *s = desc ? (__bridge_transfer NSString *)desc : @"";
                                // Ownership moved to ARC via __bridge_transfer;
                                // releasing here too crashed SpringBoard (v1.8.8).
                                s = [s stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
                                double parsedRate = [self panelRateFromDescriptionText:s machTickNs:machTickNs];
                                if (s.length > 900) {
                                    s = [[s substringToIndex:900] stringByAppendingString:@"..."];
                                }
                                if (parsedRate > 0) {
                                    [summary addObject:[NSString stringWithFormat:@"%@[%d].%@=<type %lu> %@ (parsed %.1f Hz)", cls, idx, key, (unsigned long)CFGetTypeID(values[i]), s, parsedRate]];
                                    if ([lower containsString:@"displayrefresh"]) {
                                        if (displayRefreshVal < 0) displayRefreshVal = parsedRate;
                                    } else if (otherVal < 0) {
                                        otherVal = parsedRate;
                                    }
                                } else {
                                    [summary addObject:[NSString stringWithFormat:@"%@[%d].%@=<type %lu> %@", cls, idx, key, (unsigned long)CFGetTypeID(values[i]), s]];
                                }
                            }

                            if (parsed > 0) {
                                if ([lower containsString:@"displayrefresh"]) {
                                    if (displayRefreshVal < 0) displayRefreshVal = parsed;
                                } else if ([lower containsString:@"limit"]) {
                                    if (limitVal < 0) limitVal = parsed;
                                } else if (otherVal < 0) {
                                    otherVal = parsed;
                                }
                            }
                        }
                        free(keys);
                        free(values);
                    }
                    CFRelease(props);
                }
                gObjectRelease(service);
                idx++;
            }
            gObjectRelease(iter);
        }
    }

    if (summary.count == 0) {
        [summary addObject:@"no refresh-related keys found"];
    }
    self.panelScanSummary = [summary componentsJoinedByString:@"; "];

    double foundHz = displayRefreshVal > 0 ? displayRefreshVal : (otherVal > 0 ? otherVal : limitVal);
    if (foundHz > 0) {
        self.panelRefreshRate = foundHz;
        self.hasPanelRefreshRate = YES;
    } else {
        self.hasPanelRefreshRate = NO;
    }
}

// Only accepts values at the panel rate steps real iOS hardware uses, so a
// packed IOMFB struct's length/flag words (8, 16, 32, ...) never pass as a
// refresh rate.
- (BOOL)isPlausiblePanelRate:(uint32_t)v {
    static const uint32_t steps[] = {10, 24, 30, 40, 45, 48, 60, 80, 90, 120, 144, 165, 240};
    for (size_t i = 0; i < sizeof(steps) / sizeof(steps[0]); i++) {
        if (v + 1 >= steps[i] && v - 1 <= steps[i]) return YES;
    }
    return NO;
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
