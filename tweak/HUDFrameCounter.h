#import <Foundation/Foundation.h>

// backboardd-side frame counter.
//
// The tweak is also injected into backboardd (see CAPerfHUDOverlay.plist).
// Inside backboardd the tweak does not touch UIKit at all: it hooks
// CA::Transaction::commit – the render server's per-frame commit – and
// publishes a monotonically increasing frame count plus a monotonic-second
// timestamp through a small shared mmap file. SpringBoard reads that file
// once per second and derives the *real* panel frame rate from the delta.
//
// This is the only channel that reflects what the panel actually displays:
// inside SpringBoard itself, CADisplayLink is pinned to the 60 Hz UI vsync
// track the system assigns to the process, and the display driver's
// IORegistry only exposes static capability ranges, never a live value.
FOUNDATION_EXPORT void CAPerfFrameCounterStart(void);
