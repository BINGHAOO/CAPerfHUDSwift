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

// Writes a diagnostics plist so the app can display the tweak's view of the
// shared configuration (used for troubleshooting on roothide).
- (void)writeDiagnosticsNotifyCount:(NSInteger)notifyCount;

// Path the last successful reload used, or nil when no plist was found.
@property (nonatomic, copy, readonly) NSString *usedPath;

// Appearance
@property (nonatomic, readonly) BOOL enabled;
@property (nonatomic, readonly) CGFloat windowWidth;
@property (nonatomic, readonly) CGFloat windowHeight;
@property (nonatomic, readonly) CGFloat positionX;
@property (nonatomic, readonly) CGFloat positionY;
@property (nonatomic, readonly) CGFloat fontSize;
@property (nonatomic, readonly) CGFloat backgroundOpacity;
@property (nonatomic, readonly) CGFloat cornerRadius;
@property (nonatomic, copy, readonly) NSString *textColorHex;
@property (nonatomic, copy, readonly) NSString *bgColorHex;
@property (nonatomic, readonly) BOOL showBorder;
@property (nonatomic, readonly) CGFloat borderWidth;

@end
