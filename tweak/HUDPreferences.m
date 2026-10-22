// HUDPreferences.m
#import "HUDPreferences.h"

NSString * const kCAPerfHUDPrefsDomain = @"com.binghaoo.caperfhud";
NSString * const kCAPerfHUDSettingsChangedNotification = @"com.binghaoo.caperfhud/settingsChanged";

@implementation HUDPreferences {
    NSDictionary *_prefs;
}

+ (instancetype)sharedPreferences {
    static HUDPreferences *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[HUDPreferences alloc] init];
    });
    return shared;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self reload];
    }
    return self;
}

- (void)reload {
    // Read the shared plist directly from the preferences directory.
    NSString *path = [NSString stringWithFormat:@"/var/mobile/Library/Preferences/%@.plist", kCAPerfHUDPrefsDomain];
    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:path];
    _prefs = dict ?: @{};
}

- (id)objectForKey:(NSString *)key {
    return _prefs[key];
}

- (BOOL)enabled {
    id val = [self objectForKey:@"enabled"];
    return val ? [val boolValue] : NO;
}

- (CGFloat)windowWidth {
    id val = [self objectForKey:@"windowWidth"];
    return val ? [val doubleValue] : 220;
}

- (CGFloat)windowHeight {
    id val = [self objectForKey:@"windowHeight"];
    return val ? [val doubleValue] : 80;
}

- (CGFloat)positionX {
    id val = [self objectForKey:@"positionX"];
    return val ? [val doubleValue] : 0;
}

- (CGFloat)positionY {
    id val = [self objectForKey:@"positionY"];
    return val ? [val doubleValue] : 0;
}

- (CGFloat)fontSize {
    id val = [self objectForKey:@"fontSize"];
    return val ? [val doubleValue] : 14;
}

- (CGFloat)backgroundOpacity {
    id val = [self objectForKey:@"backgroundOpacity"];
    return val ? [val doubleValue] : 0.7;
}

- (CGFloat)cornerRadius {
    id val = [self objectForKey:@"cornerRadius"];
    return val ? [val doubleValue] : 12;
}

- (NSString *)textColorHex {
    id val = [self objectForKey:@"textColorHex"];
    return val ?: @"#FFFFFF";
}

- (NSString *)bgColorHex {
    id val = [self objectForKey:@"bgColorHex"];
    return val ?: @"#000000";
}

- (BOOL)showBorder {
    id val = [self objectForKey:@"showBorder"];
    return val ? [val boolValue] : NO;
}

- (CGFloat)borderWidth {
    id val = [self objectForKey:@"borderWidth"];
    return val ? [val doubleValue] : 1;
}

@end
