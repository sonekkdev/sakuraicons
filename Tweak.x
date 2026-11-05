// SakuraIcons 0.6.0 - tinted icons (monochrome blue) on a dark card
// Config: /var/mobile/Library/Preferences/com.sonekk.sakuraicons.plist
//   enabled, hideLabels, cardColor, cardAlpha, cardRadius, grow,
//   tint (BOOL), tintColor, tintAlpha, border

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>
#import <CoreFoundation/CoreFoundation.h>

static const void *kSakuraCardKey = &kSakuraCardKey;
static const void *kSakuraTintKey = &kSakuraTintKey;
static IMP gOrigLayout = NULL;

static BOOL gEnabled = YES;
static BOOL gHideLabels = YES;
static BOOL gBorder = YES;
static BOOL gTint = YES;
static CGFloat gCardAlpha = 0.72;
static CGFloat gCardRadius = 0.24;
static CGFloat gGrow = 0.07;
static CGFloat gTintAlpha = 0.45;
static UIColor *gCardColor = nil;
static NSString *gPrefsSource = nil;
static UIColor *gTintColor = nil;


static UIColor *ColorFromHex(NSString *hex, CGFloat alpha, UIColor *fallback) {
    if (![hex isKindOfClass:[NSString class]] || hex.length < 6) return fallback;
    NSString *s = [hex stringByReplacingOccurrencesOfString:@"#" withString:@""];
    unsigned int value = 0;
    if (![[NSScanner scannerWithString:s] scanHexInt:&value]) return fallback;
    return [UIColor colorWithRed:((value >> 16) & 0xFF) / 255.0
                           green:((value >> 8) & 0xFF) / 255.0
                            blue:(value & 0xFF) / 255.0
                           alpha:alpha];
}

static NSArray<NSString *> *PrefPaths(void) {
    return @[
        @"/var/mobile/Library/Preferences/com.sonekk.sakuraicons.plist",
        @"/var/jb/var/mobile/Library/Preferences/com.sonekk.sakuraicons.plist",
        @"/var/jb/Library/Preferences/com.sonekk.sakuraicons.plist",
        @"/Library/Preferences/com.sonekk.sakuraicons.plist"
    ];
}

static NSDictionary *LoadPrefsDict(void) {
    for (NSString *p in PrefPaths()) {
        NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile:p];
        if ([d isKindOfClass:[NSDictionary class]] && d.count) {
            gPrefsSource = p;
            return d;
        }
    }
    return nil;
}

static void ReadPrefs(void) {
    NSDictionary *d = LoadPrefsDict();
    if (!d) {
        gCardColor = ColorFromHex(@"#0A1F3C", gCardAlpha, [UIColor colorWithRed:0.04 green:0.12 blue:0.24 alpha:gCardAlpha]);
        gTintColor = ColorFromHex(@"#5AA9FF", gTintAlpha, [UIColor colorWithRed:0.35 green:0.66 blue:1.0 alpha:gTintAlpha]);
        return;
    }

    id v;
    if ((v = d[@"enabled"])) gEnabled = [v boolValue];
    if ((v = d[@"hideLabels"])) gHideLabels = [v boolValue];
    if ((v = d[@"border"])) gBorder = [v boolValue];
    if ((v = d[@"tint"])) gTint = [v boolValue];
    if ((v = d[@"cardAlpha"])) gCardAlpha = [v doubleValue];
    if ((v = d[@"cardRadius"])) gCardRadius = [v doubleValue];
    if ((v = d[@"grow"])) gGrow = [v doubleValue];
    if ((v = d[@"tintAlpha"])) gTintAlpha = [v doubleValue];

    NSString *cardHex = d[@"cardColor"] ?: @"#0A1F3C";
    NSString *tintHex = d[@"tintColor"] ?: @"#5AA9FF";
    gCardColor = ColorFromHex(cardHex, gCardAlpha, [UIColor colorWithRed:0.04 green:0.12 blue:0.24 alpha:gCardAlpha]);
    gTintColor = ColorFromHex(tintHex, gTintAlpha, [UIColor colorWithRed:0.35 green:0.66 blue:1.0 alpha:gTintAlpha]);
}

static void WalkHideLabels(UIView *view, int depth) {
    if (depth > 6) return;
    for (UIView *sub in view.subviews) {
        NSString *cn = NSStringFromClass([sub class]);
        if ([cn containsString:@"Label"] || [sub isKindOfClass:[UILabel class]]) {
            sub.hidden = YES;
            sub.alpha = 0.0;
        } else {
            WalkHideLabels(sub, depth + 1);
        }
    }
}

static UIView *WalkFindIconImage(UIView *view, int depth) {
    if (depth > 6) return nil;
    for (UIView *sub in view.subviews) {
        NSString *cn = NSStringFromClass([sub class]);
        if ([cn containsString:@"Label"]) continue;
        if ([cn containsString:@"IconImage"] || [cn containsString:@"IconLayer"]) return sub;
        UIView *found = WalkFindIconImage(sub, depth + 1);
        if (found) return found;
    }
    return nil;
}

static void LayoutSakura(UIView *self, SEL _cmd) {
    if (gOrigLayout) ((void (*)(id, SEL))gOrigLayout)(self, _cmd);
    if (!gEnabled) return;

    if (gHideLabels) WalkHideLabels(self, 0);

    UIView *imageView = WalkFindIconImage(self, 0);
    if (!imageView) return;

    UIView *host = imageView.superview ?: self;
    CGRect f = imageView.frame;
    CGFloat radius = MIN(CGRectGetWidth(f), CGRectGetHeight(f)) * gCardRadius;

    /* dark card behind the icon */
    UIView *card = objc_getAssociatedObject(self, kSakuraCardKey);
    if (!card || card.superview != host) {
        card = [[UIView alloc] init];
        card.userInteractionEnabled = NO;
        card.layer.cornerCurve = kCACornerCurveContinuous;
        [host insertSubview:card belowSubview:imageView];
        objc_setAssociatedObject(self, kSakuraCardKey, card, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    CGFloat dx = CGRectGetWidth(f) * gGrow;
    CGFloat dy = CGRectGetHeight(f) * gGrow;
    card.frame = CGRectInset(f, -dx, -dy);
    card.backgroundColor = gCardColor;
    card.layer.cornerRadius = radius + MIN(dx, dy);
    card.layer.borderWidth = gBorder ? 1.0 : 0.0;
    card.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.22].CGColor;

    /* monochrome tint on top of the icon */
    if (gTint) {
        UIView *tint = objc_getAssociatedObject(self, kSakuraTintKey);
        if (!tint || tint.superview != host) {
            tint = [[UIView alloc] init];
            tint.userInteractionEnabled = NO;
            tint.layer.masksToBounds = YES;
            tint.backgroundColor = gTintColor;
            [host insertSubview:tint aboveSubview:imageView];
            objc_setAssociatedObject(self, kSakuraTintKey, tint, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        tint.frame = f;
        tint.layer.cornerRadius = radius;
        tint.backgroundColor = gTintColor;
    }
}


static NSString *DbgInfo(void) {
    BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:@"/var/mobile/Library/Preferences/com.sonekk.sakuraicons.plist"];
    NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/com.sonekk.sakuraicons.plist"];
    return [NSString stringWithFormat:@"card=%@ tint=%@ alpha=%.2f src=%@",
            d[@"cardColor"] ?: @"-", d[@"tintColor"] ?: @"-", gCardAlpha, gPrefsSource ?: @"brak"];
}

static void ShowDebugAlert(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIApplication *app = [UIApplication sharedApplication];
        UIWindow *w = nil;
        for (UIWindow *x in app.windows) { if (x.isKeyWindow) { w = x; break; } }
        if (!w) return;
        UIAlertController *a = [UIAlertController alertControllerWithTitle:@"SakuraIcons 0.9.1"
                                                                  message:DbgInfo()
                                                           preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [w.rootViewController presentViewController:a animated:YES completion:nil];
    });
}
__attribute__((constructor))
static void SakuraIconsInit(void) {
    ReadPrefs();

    ShowDebugAlert();

    Class iconView = NSClassFromString(@"SBIconView");
    if (iconView) {
        Method layout = class_getInstanceMethod(iconView, @selector(layoutSubviews));
        if (layout) {
            gOrigLayout = method_getImplementation(layout);
            method_setImplementation(layout, (IMP)LayoutSakura);
        }
    }
}
