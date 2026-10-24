// HUDPreferences.h
#import <Foundation/Foundation.h>

// Domain of the shared plist written by the CAPerfHUDSwift app.
extern NSString * const kCAPerfHUDPrefsDomain;
// Darwin notification posted by the app whenever settings change.
extern NSString * const kCAPerfHUDSettingsChangedNotification;

@interface HUDPreferences : NSObject

+ (instancetype)sharedPreferences;

// Reload from the shared plist on disk.
- (void)reload;

// Every location the app may have written its settings to (standard prefs
// directory, jbroot prefs directory, and every app data container).
- (NSArray<NSString *> *)candidatePrefsPaths;

// Writes a diagnostics plist so the app can display the tweak's view of the
// shared configuration (used for troubleshooting on roothide).
- (void)writeDiagnosticsNotifyCount:(NSInteger)notifyCount;

// Path the last successful reload used, or nil when no plist was found.
@property (nonatomic, copy, readonly) NSString *usedPath;

// Appearance
@property (nonatomic, readonly) BOOL enabled;
@property (nonatomic, readonly) CGFloat windowWidth;
@property (nonatomic, readonly) CGFloat windowHeight;
@property (nonatomic, readonly) CGFloat fontSize;
@property (nonatomic, readonly) CGFloat backgroundOpacity;
@property (nonatomic, readonly) CGFloat cornerRadius;
@property (nonatomic, copy, readonly) NSString *textColorHex;
@property (nonatomic, copy, readonly) NSString *bgColorHex;
@property (nonatomic, readonly) BOOL showBorder;
@property (nonatomic, readonly) CGFloat borderWidth;

// Which metrics appear on the overlay (defaults: FPS/CPU/MEM on, rest off).
@property (nonatomic, readonly) BOOL showFPS;
@property (nonatomic, readonly) BOOL showCPU;
@property (nonatomic, readonly) BOOL showMemory;
@property (nonatomic, readonly) BOOL showTemperature;
@property (nonatomic, readonly) BOOL showPower;
@property (nonatomic, readonly) BOOL showNetwork;
@property (nonatomic, readonly) BOOL showBattery;

// Text alignment inside the panel: 0 = left, 1 = center, 2 = right.
@property (nonatomic, readonly) NSInteger textAlignment;
// Grow the panel height to fit the selected metrics automatically.
@property (nonatomic, readonly) BOOL autoHeight;

@end
