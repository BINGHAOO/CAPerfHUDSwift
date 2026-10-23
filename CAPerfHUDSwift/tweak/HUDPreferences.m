// HUDPreferences.m
#import "HUDPreferences.h"
#import <dlfcn.h>

NSString * const kCAPerfHUDPrefsDomain = @"com.binghaoo.caperfhud";
NSString * const kCAPerfHUDSettingsChangedNotification = @"com.binghaoo.caperfhud/settingsChanged";

@implementation HUDPreferences {
    NSDictionary *_prefs;
    NSInteger _reloadCount;
    NSString *_usedPath;
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

// Every location the app could possibly have written its settings plist to:
// the standard prefs directory, the jbroot prefs directory, and the prefs
// file inside EVERY app data container (a containerized app can only persist
// its own defaults, which cfprefsd stores inside its data container).
- (NSArray<NSString *> *)candidatePrefsPaths {
    NSMutableArray *paths = [NSMutableArray array];
    NSFileManager *fm = [NSFileManager defaultManager];

    [paths addObject:[self primaryPrefsPath]];
    NSString *jbPrefs = [self jbrootPrefsPath];
    if (jbPrefs) [paths addObject:jbPrefs];

    // jbroot prefix (without the /var/... suffix), for container scanning.
    NSString *jbRoot = nil;
    if (jbPrefs) {
        NSString *suffix = [NSString stringWithFormat:@"/var/mobile/Library/Preferences/%@.plist", kCAPerfHUDPrefsDomain];
        if ([jbPrefs hasSuffix:suffix]) {
            jbRoot = [jbPrefs substringToIndex:([jbPrefs length] - [suffix length])];
        }
    }

    for (NSString *mobileRoot in [NSArray arrayWithObjects:@"/var/mobile",
                                                            jbRoot ? [jbRoot stringByAppendingPathComponent:@"var/mobile"] : nil, nil]) {
        NSString *appsRoot = [mobileRoot stringByAppendingPathComponent:@"Containers/Data/Application"];
        NSArray *uuids = [fm contentsOfDirectoryAtPath:appsRoot error:nil];
        for (NSString *uuid in uuids) {
            NSString *p = [appsRoot stringByAppendingPathComponent:uuid];
            p = [p stringByAppendingPathComponent:@"Library/Preferences"];
            p = [p stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.plist", kCAPerfHUDPrefsDomain]];
            [paths addObject:p];
        }
    }

    return paths;
}

- (void)reload {
    NSFileManager *fm = [NSFileManager defaultManager];

    // Stat every candidate, then parse newest-first until one yields a
    // non-empty dictionary. Newest wins so concurrent channels (direct write
    // + defaults suite) always converge on the freshest settings.
    NSMutableArray<NSDictionary *> *candidates = [NSMutableArray array];
    for (NSString *path in [self candidatePrefsPaths]) {
        NSDictionary *attrs = [fm attributesOfItemAtPath:path error:nil];
        if (!attrs) continue;
        [candidates addObject:@{@"path": path,
                                @"date": attrs[NSFileModificationDate] ?: [NSDate distantPast]}];
    }
    [candidates sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        return [b[@"date"] compare:a[@"date"]];
    }];

    for (NSDictionary *candidate in candidates) {
        NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:candidate[@"path"]];
        if (dict.count > 0) {
            _prefs = dict;
            _usedPath = candidate[@"path"];
            _reloadCount++;
            return;
        }
    }

    _prefs = @{};
    _usedPath = nil;
    _reloadCount++;
}

// Diagnostics for the app's "Diagnostics" page. SpringBoard can write to
// /var/mobile/Library/Preferences freely; the diag file is additionally
// written next to the prefs file that was actually used, so even a fully
// containerized app can read it from its own data container.
- (void)writeDiagnosticsNotifyCount:(NSInteger)notifyCount {
    NSMutableDictionary *diag = [NSMutableDictionary dictionary];
    diag[@"lastReload"] = [NSDate date];
    diag[@"reloadCount"] = @(_reloadCount);
    diag[@"notifyCount"] = @(notifyCount);
    diag[@"usedPath"] = _usedPath ?: @"";
    diag[@"prefsFound"] = @(_prefs.count > 0);
    diag[@"prefsKeyCount"] = @(_prefs.count);
    diag[@"enabled"] = @(self.enabled);
    diag[@"windowWidth"] = @(self.windowWidth);
    diag[@"windowHeight"] = @(self.windowHeight);
    diag[@"fontSize"] = @(self.fontSize);
    diag[@"primaryPath"] = [self primaryPrefsPath];

    NSFileManager *fm = [NSFileManager defaultManager];
    diag[@"primaryExists"] = @([fm fileExistsAtPath:[self primaryPrefsPath]]);
    NSString *jb = [self jbrootPrefsPath];
    diag[@"jbrootPrefsPath"] = jb ?: @"";
    diag[@"jbrootExists"] = jb ? @([fm fileExistsAtPath:jb]) : @NO;
    diag[@"candidateCount"] = @([self candidatePrefsPaths].count);

    NSString *diagPath = [NSString stringWithFormat:@"/var/mobile/Library/Preferences/%@.diag.plist", kCAPerfHUDPrefsDomain];
    [diag writeToFile:diagPath atomically:YES];

    // Mirror the diag next to the prefs file actually in use (app container
    // or jbroot), so the app can read it even when sandboxed.
    if (_usedPath && ![diagPath isEqualToString:_usedPath]) {
        NSString *dir = [_usedPath stringByDeletingLastPathComponent];
        [diag writeToFile:[dir stringByAppendingPathComponent:[diagPath lastPathComponent]] atomically:YES];
    }
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
