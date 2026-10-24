#import "HUDFrameCounter.h"
#import <substrate.h>
#import <fcntl.h>
#import <sys/mman.h>
#import <sys/stat.h>
#import <time.h>
#import <unistd.h>

// Mangled CA::Transaction::commit() – called once per frame by the render
// server inside backboardd.
static const char *kCommitSymbol = "__ZN2CA11Transaction6commitEv";
static const char *kSharedPath = "/var/mobile/Library/Preferences/.caperfhud.framerate";
static const size_t kSharedSize = 4096;

static void (*orig_CATransactionCommit)(void);
static uint64_t s_frameCount = 0;
static uint64_t s_lastFlushSec = 0;
static volatile uint64_t *s_sharedPage = NULL;

static void CommitHook(void) {
    s_frameCount++;
    if (s_sharedPage) {
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
    orig_CATransactionCommit();
}

void CAPerfFrameCounterStart(void) {
    void *symbol = MSFindSymbol(NULL, kCommitSymbol);
    if (!symbol) return;

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

    MSHookFunction(symbol, (void *)CommitHook, (void **)&orig_CATransactionCommit);
}
