// HUDPreferences.m
#import "HUDPreferences.h"
#import <dlfcn.h>

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

// Standard location, shared with the app.
- (NSString *)primaryPrefsPath {
    return [NSString stringWithFormat:@"/var/mobile/Library/Preferences/%@.plist", kCAPerfHUDPrefsDomain];
}

// On roothide the app may only be able to write inside the hidden jbroot.
// Derive the jbroot prefix from this tweak's own dylib path
// ("/var/containers/Bundle/Application/.jbroot-XXXXXXXX/...").
- (NSString *)jbrootPrefsPath {
    Dl_info info;
    if (!dladdr((void *)&kCAPerfHUDPrefsDomain, &info) || info.dli_fname == NULL) return nil;

    NSString *selfPath = [NSString stringWithUTF8String:info.dli_fname];
    NSRange marker = [selfPath rangeOfString:@"/.jbroot-"];
    if (marker.location == NSNotFound) return nil;

    NSString *after = [selfPath substringFromIndex:NSMaxRange(marker)];
    NSRange slash = [after rangeOfString:@"/"];
    if (slash.location == NSNotFound) return nil;

    NSString *jbroot = [[selfPath substringToIndex:marker.location]
                        stringByAppendingFormat:@"/%@", [after substringToIndex:slash.location]];
    return [NSString stringWithFormat:@"%@/var/mobile/Library/Preferences/%@.plist", jbroot, kCAPerfHUDPrefsDomain];
}

- (void)reload {
    NSString *primary = [self primaryPrefsPath];
    NSString *jbPath = [self jbrootPrefsPath];

    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:primary];
    NSDictionary *jbDict = jbPath ? [NSDictionary dictionaryWithContentsOfFile:jbPath] : nil;

    // When both exist, prefer the most recently modified one.
    if (jbDict) {
        NSFileManager *fm = [NSFileManager defaultManager];
        NSDate *d1 = [fm attributesOfItemAtPath:primary error:nil][NSFileModificationDate];
        NSDate *d2 = [fm attributesOfItemAtPath:jbPath error:nil][NSFileModificationDate];
        if (!d1 || (d2 && [d2 compare:d1] == NSOrderedDescending)) {
            dict = jbDict;
        }
    }

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
