// Sonekk Lock 3.1.0 - glass winter lock screen for Switzach (iOS 27, SpringBoard tweak).
// Single-file Objective-C. UIKit + QuartzCore only. No third-party code.
// The kLockWallpaperB64 constant below is filled in by the build (empty here on purpose).

// SonekkLock.m - glass winter lock screen for Switzach (no PIN)
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
// The wallpaper is injected separately as a base64 JPEG string:
//   static NSString *const kLockWallpaperB64 = @"...";  (do NOT change it)
static NSString *const kLockWallpaperB64 = @"";

static UIImage *SnowflakeImage(void) {
    UIGraphicsImageRenderer *r = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(7, 7)];
    return [r imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
        [[UIColor colorWithWhite:1 alpha:0.85] setFill];
        [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(0, 0, 7, 7)] fill];
    }];
}

@interface SonekkLockView : UIView
@property (nonatomic, strong) UILabel *timeLabel;
@property (nonatomic, strong) UILabel *dateLabel;
@property (nonatomic, strong) UIImageView *wallpaper;
@property (nonatomic, strong) UILabel *hintLabel;
@property (nonatomic, strong) UIView *scanButton;
@property (nonatomic, strong) CAShapeLayer *scanRing;
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic) BOOL unlocking;
@end

@implementation SonekkLockView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;
    self.backgroundColor = [UIColor blackColor];
    self.clipsToBounds = YES;
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

    NSData *wd = [[NSData alloc] initWithBase64EncodedString:kLockWallpaperB64 options:NSDataBase64DecodingIgnoreUnknownCharacters];
    UIImage *wall = wd ? [UIImage imageWithData:wd] : nil;
    _wallpaper = [[UIImageView alloc] initWithImage:wall];
    _wallpaper.frame = self.bounds;
    _wallpaper.contentMode = UIViewContentModeScaleAspectFill;
    _wallpaper.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self addSubview:_wallpaper];

    // deep blue-grey tint
    CAGradientLayer *grad = [CAGradientLayer layer];
    grad.frame = self.bounds;
    grad.colors = @[(id)[UIColor colorWithRed:0.05 green:0.09 blue:0.17 alpha:0.30].CGColor,
                    (id)[UIColor colorWithRed:0.02 green:0.04 blue:0.08 alpha:0.72].CGColor];
    grad.startPoint = CGPointMake(0.5, 0.0);
    grad.endPoint = CGPointMake(0.5, 1.0);
    [self.layer addSublayer:grad];

    // snow
    CAEmitterLayer *snow = [CAEmitterLayer layer];
    snow.frame = self.bounds;
    snow.emitterPosition = CGPointMake(self.bounds.size.width / 2, -20);
    snow.emitterSize = CGSizeMake(self.bounds.size.width, 1);
    snow.emitterMode = kCAEmitterLayerLine;
    snow.emitterShape = kCAEmitterLayerLine;
    CAEmitterCell *cell = [CAEmitterCell emitterCell];
    cell.contents = (id)SnowflakeImage().CGImage;
    cell.birthRate = 3.2;
    cell.lifetime = 16;
    cell.velocity = 26;
    cell.velocityRange = 18;
    cell.yAcceleration = 8;
    cell.scale = 0.30;
    cell.scaleRange = 0.25;
    cell.alphaSpeed = -0.04;
    cell.spin = 0.4;
    cell.spinRange = 1.0;
    snow.emitterCells = @[cell];
    [self.layer addSublayer:snow];

    // glass clock panel
    UIVisualEffectView *glass = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark]];
    glass.layer.cornerRadius = 30;
    glass.layer.cornerCurve = kCACornerCurveContinuous;
    glass.clipsToBounds = YES;
    glass.layer.borderWidth = 0.5;
    glass.layer.borderColor = [UIColor colorWithRed:0.45 green:0.70 blue:0.95 alpha:0.18].CGColor;
    glass.tag = 20;
    [self addSubview:glass];

    _timeLabel = [[UILabel alloc] init];
    UIFont *baseFont = [UIFont systemFontOfSize:92 weight:UIFontWeightBold];
    UIFontDescriptor *roundedDesc = [baseFont.fontDescriptor fontDescriptorWithDesign:UIFontDescriptorSystemDesignRounded];
    _timeLabel.font = roundedDesc ? [UIFont fontWithDescriptor:roundedDesc size:92] : baseFont;
    _timeLabel.textColor = UIColor.whiteColor;
    _timeLabel.textAlignment = NSTextAlignmentCenter;
    _timeLabel.layer.shadowColor = [UIColor colorWithRed:0.4 green:0.7 blue:1 alpha:0.45].CGColor;
    _timeLabel.layer.shadowRadius = 8;
    _timeLabel.layer.shadowOpacity = 0.9;
    _timeLabel.layer.shadowOffset = CGSizeZero;
    [self addSubview:_timeLabel];

    _dateLabel = [[UILabel alloc] init];
    _dateLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    _dateLabel.textColor = [UIColor colorWithWhite:1 alpha:0.78];
    _dateLabel.textAlignment = NSTextAlignmentCenter;
    [self addSubview:_dateLabel];

    UIImageView *lock = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"lock.fill"]];
    lock.tintColor = [UIColor colorWithRed:0.62 green:0.82 blue:1 alpha:0.9];
    lock.contentMode = UIViewContentModeScaleAspectFit;
    lock.tag = 21;
    [self addSubview:lock];

    // fingerprint scanner
    _scanButton = [[UIView alloc] init];
    _scanButton.backgroundColor = [UIColor colorWithWhite:1 alpha:0.08];
    _scanButton.layer.cornerRadius = 38;
    _scanButton.layer.borderWidth = 1.0;
    _scanButton.layer.borderColor = [UIColor colorWithRed:0.55 green:0.78 blue:1 alpha:0.55].CGColor;
    _scanButton.tag = 22;
    [_scanButton addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(scanTap)]];
    [self addSubview:_scanButton];

    UIView *ringHost = [[UIView alloc] initWithFrame:CGRectMake(-1, -1, 78, 78)];
    ringHost.userInteractionEnabled = NO;
    [_scanButton addSubview:ringHost];
    _scanRing = [CAShapeLayer layer];
    _scanRing.frame = ringHost.bounds;
    _scanRing.path = [UIBezierPath bezierPathWithOvalInRect:CGRectInset(ringHost.bounds, 3, 3)].CGPath;
    _scanRing.strokeColor = [UIColor colorWithRed:0.48 green:0.74 blue:1 alpha:1].CGColor;
    _scanRing.fillColor = UIColor.clearColor.CGColor;
    _scanRing.lineWidth = 3;
    _scanRing.strokeEnd = 0;
    _scanRing.lineCap = kCALineCapRound;
    [ringHost.layer addSublayer:_scanRing];

    UIImageView *finger = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"touchid"]];
    finger.tintColor = [UIColor colorWithWhite:1 alpha:0.9];
    finger.contentMode = UIViewContentModeScaleAspectFit;
    finger.frame = CGRectMake(0, 0, 34, 34);
    finger.center = CGPointMake(38, 38);
    [_scanButton addSubview:finger];

    _hintLabel = [[UILabel alloc] init];
    _hintLabel.text = @"Dotknij, aby odblokowa\u0107";
    _hintLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    _hintLabel.textColor = [UIColor colorWithWhite:1 alpha:0.65];
    _hintLabel.textAlignment = NSTextAlignmentCenter;
    [self addSubview:_hintLabel];

    UIView *bar = [[UIView alloc] init];
    bar.backgroundColor = [UIColor colorWithWhite:1 alpha:0.8];
    bar.layer.cornerRadius = 2.5;
    bar.tag = 23;
    [self addSubview:bar];

    _timer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(tick) userInfo:nil repeats:YES];
    [self tick];
    return self;
}

- (void)tick {
    NSDateFormatter *f = [NSDateFormatter new];
    f.dateFormat = @"HH:mm";
    _timeLabel.text = [f stringFromDate:[NSDate date]];
    f.locale = [NSLocale localeWithLocaleIdentifier:@"pl_PL"];
    f.dateFormat = @"EEEE, d MMMM";
    _dateLabel.text = [f stringFromDate:[NSDate date]];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat W = self.bounds.size.width, H = self.bounds.size.height;
    UIView *glass = [self viewWithTag:20];
    glass.frame = CGRectMake(26, H * 0.16, W - 52, 176);
    _timeLabel.frame = CGRectMake(0, H * 0.16 + 14, W, 104);
    _dateLabel.frame = CGRectMake(0, H * 0.16 + 120, W, 24);
    UIView *lock = [self viewWithTag:21];
    lock.frame = CGRectMake((W - 18)/2, 66, 18, 22);
    _scanButton.center = CGPointMake(W/2, H - 132);
    _scanButton.bounds = CGRectMake(0, 0, 76, 76);
    _hintLabel.frame = CGRectMake(0, H - 82, W, 18);
    UIView *bar = [self viewWithTag:23];
    bar.frame = CGRectMake((W - 134)/2, H - 30, 134, 5);
}

- (void)scanTap {
    if (_unlocking) return;
    _unlocking = YES;
    UIImpactFeedbackGenerator *h = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [h impactOccurred];

    CABasicAnimation *a = [CABasicAnimation animationWithKeyPath:@"strokeEnd"];
    a.fromValue = @0;
    a.toValue = @1;
    a.duration = 0.35;
    a.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    _scanRing.strokeEnd = 1;
    [_scanRing addAnimation:a forKey:@"scan"];

    [UIView animateWithDuration:0.35 animations:^{
        self->_scanButton.transform = CGAffineTransformMakeScale(1.06, 1.06);
        self->_scanButton.backgroundColor = [UIColor colorWithRed:0.30 green:0.58 blue:0.86 alpha:0.24];
    }];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UINotificationFeedbackGenerator *n = [UINotificationFeedbackGenerator new];
        [n notificationOccurred:UINotificationFeedbackTypeSuccess];
        [self->_timer invalidate];
        UIWindow *win = self.window;
        UIView *home = win.rootViewController.view;
        home.transform = CGAffineTransformMakeScale(0.97, 0.97);
        [UIView animateWithDuration:0.42 delay:0 usingSpringWithDamping:0.9 initialSpringVelocity:0.3 options:UIViewAnimationOptionAllowUserInteraction animations:^{
            home.transform = CGAffineTransformIdentity;
            self.transform = CGAffineTransformMakeScale(1.04, 1.04);
            self.alpha = 0;
        } completion:^(BOOL f) { [self removeFromSuperview]; }];
    });
}

@end

static void ShowLock(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            UIWindow *win = UIApplication.sharedApplication.keyWindow;
            if (!win) win = UIApplication.sharedApplication.windows.firstObject;
            if (!win) {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ ShowLock(); });
                return;
            }
            if ([win viewWithTag:99188]) return;
            SonekkLockView *lock = [[SonekkLockView alloc] initWithFrame:win.bounds];
            lock.tag = 99188;
            [win addSubview:lock];
        } @catch (NSException *e) { }
    });
}

__attribute__((constructor))
static void SonekkLockInit(void) {
    @autoreleasepool {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ ShowLock(); });
    }
}
