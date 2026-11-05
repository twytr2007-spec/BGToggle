#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

static AVAudioPlayer *player;
static UIBackgroundTaskIdentifier bgTask = 0;
static BOOL bgEnabled = NO;
static UIWindow *btnWindow;
static UIButton *btn;

static void put32(NSMutableData *d, uint32_t v) { [d appendBytes:&v length:4]; }
static void put16(NSMutableData *d, uint16_t v) { [d appendBytes:&v length:2]; }

// 1 second of silent 8kHz mono 16-bit WAV, generated in memory
static NSData *SilentWav(void) {
    uint32_t sr = 8000, dataSize = sr * 2;
    NSMutableData *d = [NSMutableData data];
    [d appendBytes:"RIFF" length:4]; put32(d, 36 + dataSize);
    [d appendBytes:"WAVEfmt " length:8]; put32(d, 16);
    put16(d, 1); put16(d, 1); put32(d, sr); put32(d, sr * 2); put16(d, 2); put16(d, 16);
    [d appendBytes:"data" length:4]; put32(d, dataSize);
    [d increaseLengthBy:dataSize];
    return d;
}

static void StartBG(void) {
    NSError *e = nil;
    AVAudioSession *s = [AVAudioSession sharedInstance];
    [s setCategory:AVAudioSessionCategoryPlayback
       withOptions:AVAudioSessionCategoryOptionMixWithOthers error:&e];
    [s setActive:YES error:&e];
    if (!player) {
        player = [[AVAudioPlayer alloc] initWithData:SilentWav() error:&e];
        player.numberOfLoops = -1;
    }
    [player prepareToPlay];
    [player play];
    if (bgTask == UIBackgroundTaskInvalid) {
        bgTask = [UIApplication.sharedApplication beginBackgroundTaskWithExpirationHandler:^{
            [UIApplication.sharedApplication endBackgroundTask:bgTask];
            bgTask = UIBackgroundTaskInvalid;
        }];
    }
}

static void StopBG(void) {
    [player stop];
    player = nil;
    [[AVAudioSession sharedInstance] setActive:NO
        withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:nil];
    if (bgTask != UIBackgroundTaskInvalid) {
        [UIApplication.sharedApplication endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    }
}

static void RefreshButton(void) {
    if (bgEnabled) {
        [btn setTitle:@"إيقاف التشغيل بالخلفية" forState:UIControlStateNormal];
        btn.backgroundColor = [UIColor colorWithRed:0.85 green:0.15 blue:0.15 alpha:0.92];
    } else {
        [btn setTitle:@"تشغيل بالخلفية" forState:UIControlStateNormal];
        btn.backgroundColor = [UIColor colorWithRed:0.1 green:0.65 blue:0.25 alpha:0.92];
    }
}

@interface BGHelper : NSObject
+ (void)toggle;
+ (void)pan:(UIPanGestureRecognizer *)g;
+ (void)interrupted:(NSNotification *)n;
@end

@implementation BGHelper
+ (void)toggle {
    bgEnabled = !bgEnabled;
    bgEnabled ? StartBG() : StopBG();
    RefreshButton();
}
+ (void)pan:(UIPanGestureRecognizer *)g {
    CGPoint t = [g translationInView:btnWindow];
    btnWindow.center = CGPointMake(btnWindow.center.x + t.x, btnWindow.center.y + t.y);
    [g setTranslation:CGPointZero inView:btnWindow];
}
+ (void)interrupted:(NSNotification *)n {
    NSUInteger type = [n.userInfo[AVAudioSessionInterruptionTypeKey] unsignedIntegerValue];
    if (bgEnabled && type == AVAudioSessionInterruptionTypeEnded) StartBG();
}
@end

static void ShowButton(void) {
    if (btnWindow) return;
    UIWindowScene *scene = nil;
    for (UIScene *sc in UIApplication.sharedApplication.connectedScenes) {
        if ([sc isKindOfClass:UIWindowScene.class] &&
            sc.activationState == UISceneActivationStateForegroundActive) {
            scene = (UIWindowScene *)sc; break;
        }
    }
    CGRect frame = CGRectMake(20, 100, 170, 44);
    btnWindow = scene ? [[UIWindow alloc] initWithWindowScene:scene]
                      : [[UIWindow alloc] initWithFrame:frame];
    btnWindow.frame = frame;
    btnWindow.windowLevel = UIWindowLevelAlert + 100;
    btnWindow.backgroundColor = UIColor.clearColor;
    btnWindow.rootViewController = [UIViewController new];

    btn = [UIButton buttonWithType:UIButtonTypeSystem];
    btn.frame = btnWindow.bounds;
    btn.layer.cornerRadius = 12;
    btn.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    [btn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    [btn addTarget:BGHelper.class action:@selector(toggle) forControlEvents:UIControlEventTouchUpInside];
    [btn addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:BGHelper.class action:@selector(pan:)]];
    [btnWindow.rootViewController.view addSubview:btn];
    RefreshButton();
    btnWindow.hidden = NO;
}

__attribute__((constructor)) static void init(void) {
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
        object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *n) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{ ShowButton(); });
        }];
    [[NSNotificationCenter defaultCenter] addObserver:BGHelper.class
        selector:@selector(interrupted:) name:AVAudioSessionInterruptionNotification object:nil];
}
