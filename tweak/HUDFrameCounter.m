#import "HUDFrameCounter.h"
#import <QuartzCore/QuartzCore.h>
#import <fcntl.h>
#import <sys/mman.h>
#import <time.h>
#import <unistd.h>

// backboardd-side frame counter.
//
// backboardd owns the render server's vsync track, so a CADisplayLink
// scheduled here ticks at the real panel rate (120 Hz on ProMotion) –
// unlike SpringBoard, whose display links are pinned to the 60 Hz UI track.
// CADisplayLink lives in QuartzCore; no UIKit API is touched, so this is
// safe to run inside backboardd.
//
// The counter and a monotonic-second timestamp are published through a
// small shared mmap file; SpringBoard reads the file once per second and
// derives the true frame rate from the delta.

static const char *kSharedPath = "/var/mobile/Library/Preferences/.caperfhud.framerate";
static const size_t kSharedSize = 4096;

static volatile uint64_t *s_sharedPage = NULL;
static uint64_t s_frameCount = 0;
static uint64_t s_lastFlushSec = 0;

static void BBFlushCounter(void) {
    if (!s_sharedPage) return;
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    uint64_t sec = (uint64_t)ts.tv_sec;
    if (sec != s_lastFlushSec) {
        // Publish count first, timestamp last: a reader that observes the
        // new timestamp is guaranteed to read the matching count (aligned
        // 64-bit stores are atomic on arm64).
        s_sharedPage[0] = s_frameCount;
        s_sharedPage[1] = sec;
        s_lastFlushSec = sec;
    }
}

@interface _CAPerfBBFrameTarget : NSObject
- (void)tick:(CADisplayLink *)link;
@end

@implementation _CAPerfBBFrameTarget
- (void)tick:(CADisplayLink *)link {
    (void)link;
    s_frameCount++;
    BBFlushCounter();
}
@end

void CAPerfFrameCounterStart(void) {
    int fd = open(kSharedPath, O_RDWR | O_CREAT, 0644);
    if (fd < 0) return;
    if (ftruncate(fd, (off_t)kSharedSize) != 0) {
        close(fd);
        return;
    }
    void *page = mmap(NULL, kSharedSize, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    close(fd);
    if (page == MAP_FAILED) return;

    s_sharedPage = (volatile uint64_t *)page;
    s_sharedPage[0] = 0;
    s_sharedPage[1] = 0;

    dispatch_async(dispatch_get_main_queue(), ^{
        CADisplayLink *link = [CADisplayLink displayLinkWithTarget:[_CAPerfBBFrameTarget new]
                                                          selector:@selector(tick:)];
        if (@available(iOS 15.0, *)) {
            link.preferredFrameRateRange = CAFrameRateRangeMake(120.0f, 120.0f, 120.0f);
        } else {
            link.preferredFramesPerSecond = 120;
        }
        [link addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    });
}
