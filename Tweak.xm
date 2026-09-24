#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <dispatch/dispatch.h>
#import <objc/runtime.h>
#import <math.h>
#import "ASAnalogRenderer.h"

static NSString * const ASPrefsDomain = @"com.faz.analogprefs";
static CFStringRef const ASPrefsChangedNotification = CFSTR("com.faz.analogprefs/ReloadPrefs");

static BOOL gStatusBarEnabled = YES;
static BOOL gLockScreenEnabled = NO;
static __weak id gCurrentLockController = nil;
static __weak id gCurrentDateView = nil;

static const void *ASContainerKey = &ASContainerKey;
static const void *ASClockImageViewKey = &ASClockImageViewKey;
static const void *ASDateLabelKey = &ASDateLabelKey;
static const void *ASTimerKey = &ASTimerKey;
static const void *ASLastMinuteKey = &ASLastMinuteKey;
static const void *ASLastLayoutStateKey = &ASLastLayoutStateKey;
static const void *ASChargingHiddenKey = &ASChargingHiddenKey;
static const void *ASNativeLabelHiddenStateKey = &ASNativeLabelHiddenStateKey;

static void ASUpdateDateFromDateView(id dateView);

@interface _UILegibilityImageSet : NSObject
+ (id)imageFromImage:(UIImage *)image withShadowImage:(UIImage *)shadowImage;
@end

@interface NSObject (AnalogStatusPrivate)
- (id)foregroundStyle;
- (NSInteger)legibilityStyle;
- (UIColor *)textColorForStyle:(NSInteger)style;
- (BOOL)isShowingMediaControls;
- (BOOL)hasNotifications;
- (UIScrollView *)scrollView;
@end

static id ASSafeValueForKey(id object, NSString *key) {
    if (!object || key.length == 0) return nil;
    @try {
        return [object valueForKey:key];
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

static BOOL ASPreferenceBool(NSString *key, BOOL fallback) {
    CFPreferencesAppSynchronize((__bridge CFStringRef)ASPrefsDomain);
    CFPropertyListRef value = CFPreferencesCopyAppValue((__bridge CFStringRef)key,
                                                         (__bridge CFStringRef)ASPrefsDomain);
    if (!value) return fallback;
    BOOL result = fallback;
    if (CFGetTypeID(value) == CFBooleanGetTypeID()) {
        result = CFBooleanGetValue((CFBooleanRef)value);
    } else if (CFGetTypeID(value) == CFNumberGetTypeID()) {
        int number = fallback ? 1 : 0;
        CFNumberGetValue((CFNumberRef)value, kCFNumberIntType, &number);
        result = number != 0;
    }
    CFRelease(value);
    return result;
}

static void ASLoadPreferences(void) {
    gStatusBarEnabled = ASPreferenceBool(@"SBEnabled", YES);
    gLockScreenEnabled = ASPreferenceBool(@"LSEnabled", NO);
    ASClearAnalogClockCache();
}

static UIView *ASContainer(id controller) {
    return objc_getAssociatedObject(controller, ASContainerKey);
}

static UIImageView *ASClockImageView(id controller) {
    return objc_getAssociatedObject(controller, ASClockImageViewKey);
}

static UILabel *ASDateLabel(id controller) {
    return objc_getAssociatedObject(controller, ASDateLabelKey);
}

static NSTimer *ASClockTimer(id controller) {
    return objc_getAssociatedObject(controller, ASTimerKey);
}

static UIView *ASLockHostView(id controller) {
    UIView *rootView = [controller respondsToSelector:@selector(view)] ? [controller view] : nil;
    if (!rootView) return nil;

    if ([rootView respondsToSelector:@selector(scrollView)]) {
        id candidate = [(id)rootView scrollView];
        if ([candidate isKindOfClass:[UIView class]]) return candidate;
    }
    return rootView;
}

static void ASSetLockClockHidden(id controller, BOOL hidden) {
    ASContainer(controller).hidden = hidden;
}

static NSInteger ASMinuteStamp(NSDate *date) {
    NSDateComponents *parts = [[NSCalendar currentCalendar] components:(NSCalendarUnitYear |
                                                                        NSCalendarUnitMonth |
                                                                        NSCalendarUnitDay |
                                                                        NSCalendarUnitHour |
                                                                        NSCalendarUnitMinute)
                                                              fromDate:date];
    return (((((parts.year * 13) + parts.month) * 32 + parts.day) * 24 + parts.hour) * 60 + parts.minute);
}

static void ASApplyLockLayout(id controller, BOOL forceImage) {
    if (!controller || !gLockScreenEnabled) {
        if (controller) ASSetLockClockHidden(controller, YES);
        return;
    }

    UIView *container = ASContainer(controller);
    UIImageView *clockView = ASClockImageView(controller);
    UILabel *dateLabel = ASDateLabel(controller);
    if (!container || !clockView || !dateLabel) return;

    NSNumber *chargingHidden = objc_getAssociatedObject(controller, ASChargingHiddenKey);
    if (chargingHidden.boolValue) {
        container.hidden = YES;
        return;
    }

    BOOL showingMedia = [controller respondsToSelector:@selector(isShowingMediaControls)] &&
                        [controller isShowingMediaControls];
    if (showingMedia) {
        container.hidden = YES;
        return;
    }

    BOOL hasNotifications = [controller respondsToSelector:@selector(hasNotifications)] &&
                            [controller hasNotifications];
    container.hidden = NO;

    UIView *hostView = ASContainer(controller).superview ?: ASLockHostView(controller);
    CGFloat screenWidth = hostView ? CGRectGetWidth(hostView.bounds) : CGRectGetWidth([UIScreen mainScreen].bounds);
    CGFloat diameter = hasNotifications ? 119.0 : 200.0;
    CGFloat hourLength = hasNotifications ? 29.75 : 50.0;
    CGFloat minuteLength = hasNotifications ? 50.575 : 85.0;
    CGFloat containerY = hasNotifications ? 28.5 : 30.0;
    CGFloat containerHeight = hasNotifications ? 140.0 : 221.0;
    CGFloat dateY = hasNotifications ? 121.0 : 202.0;

    container.frame = CGRectMake(0.0, containerY, screenWidth, containerHeight);
    clockView.frame = CGRectMake((screenWidth - diameter) * 0.5, 0.0, diameter, diameter);
    dateLabel.frame = CGRectMake(0.0, dateY, screenWidth, 21.0);

    NSInteger layoutState = hasNotifications ? 1 : 0;
    NSNumber *lastState = objc_getAssociatedObject(controller, ASLastLayoutStateKey);
    NSDate *now = [NSDate date];
    NSInteger minuteStamp = ASMinuteStamp(now);
    NSNumber *lastMinute = objc_getAssociatedObject(controller, ASLastMinuteKey);

    BOOL stateChanged = !lastState || lastState.integerValue != layoutState;
    BOOL minuteChanged = !lastMinute || lastMinute.integerValue != minuteStamp;
    if (minuteChanged && gCurrentDateView) {
        ASUpdateDateFromDateView(gCurrentDateView);
    }

    if (forceImage || stateChanged || minuteChanged || !clockView.image) {
        clockView.image = ASAnalogClockImage(diameter,
                                             [UIColor whiteColor],
                                             hourLength,
                                             minuteLength,
                                             2.5,
                                             now);
        objc_setAssociatedObject(controller, ASLastMinuteKey, @(minuteStamp), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(controller, ASLastLayoutStateKey, @(layoutState), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

@interface ASClockTimerTarget : NSObject
@property (nonatomic, weak) id controller;
- (void)tick:(NSTimer *)timer;
@end

@implementation ASClockTimerTarget
- (void)tick:(NSTimer *)timer {
    id controller = self.controller;
    if (!controller) {
        [timer invalidate];
        return;
    }
    ASApplyLockLayout(controller, NO);
}
@end

static const void *ASTimerTargetKey = &ASTimerTargetKey;

static void ASScheduleClockTimer(id controller) {
    NSTimer *existing = ASClockTimer(controller);
    if (existing.valid) return;

    ASClockTimerTarget *target = [ASClockTimerTarget new];
    target.controller = controller;
    objc_setAssociatedObject(controller, ASTimerTargetKey, target, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    NSTimer *timer = [NSTimer timerWithTimeInterval:1.0
                                            target:target
                                          selector:@selector(tick:)
                                          userInfo:nil
                                           repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
    objc_setAssociatedObject(controller, ASTimerKey, timer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void ASStopClockTimer(id controller) {
    NSTimer *timer = ASClockTimer(controller);
    [timer invalidate];
    objc_setAssociatedObject(controller, ASTimerKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(controller, ASTimerTargetKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void ASInstallLockClock(id controller) {
    if (!controller || !gLockScreenEnabled) return;
    gCurrentLockController = controller;

    UIView *container = ASContainer(controller);
    if (!container) {
        container = [[UIView alloc] initWithFrame:CGRectZero];
        container.backgroundColor = [UIColor clearColor];
        container.userInteractionEnabled = NO;
        container.autoresizingMask = UIViewAutoresizingFlexibleWidth;

        UIImageView *clockView = [[UIImageView alloc] initWithFrame:CGRectZero];
        clockView.contentMode = UIViewContentModeScaleAspectFit;
        clockView.userInteractionEnabled = NO;

        UILabel *dateLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        dateLabel.backgroundColor = [UIColor clearColor];
        dateLabel.textColor = [UIColor whiteColor];
        dateLabel.textAlignment = NSTextAlignmentCenter;
        dateLabel.userInteractionEnabled = NO;

        [container addSubview:clockView];
        [container addSubview:dateLabel];

        UIView *host = ASLockHostView(controller);
        if (!host) return;
        [host addSubview:container];

        objc_setAssociatedObject(controller, ASContainerKey, container, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(controller, ASClockImageViewKey, clockView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(controller, ASDateLabelKey, dateLabel, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    ASScheduleClockTimer(controller);
    ASApplyLockLayout(controller, YES);
}

static void ASSetOriginalDateViewHidden(id dateView, BOOL hidden) {
    static NSArray *keys;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        keys = @[@"_timeLabel", @"_legibilityTimeLabel", @"_legibilityDateLabel", @"_dateLabel"];
    });

    for (NSString *key in keys) {
        id label = ASSafeValueForKey(dateView, key);
        if (![label respondsToSelector:@selector(setHidden:)]) continue;

        if (hidden) {
            if (!objc_getAssociatedObject(label, ASNativeLabelHiddenStateKey)) {
                BOOL wasHidden = [label respondsToSelector:@selector(isHidden)] ? [label isHidden] : NO;
                objc_setAssociatedObject(label, ASNativeLabelHiddenStateKey, @(wasHidden), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            }
            [label setHidden:YES];
        } else {
            NSNumber *savedState = objc_getAssociatedObject(label, ASNativeLabelHiddenStateKey);
            if (savedState) {
                [label setHidden:savedState.boolValue];
                objc_setAssociatedObject(label, ASNativeLabelHiddenStateKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            }
        }
    }
}

static void ASUpdateDateFromDateView(id dateView) {
    id nativeDateLabel = ASSafeValueForKey(dateView, @"_dateLabel");
    NSString *text = [nativeDateLabel respondsToSelector:@selector(text)] ? [nativeDateLabel text] : nil;
    if (text.length == 0) {
        nativeDateLabel = ASSafeValueForKey(dateView, @"_legibilityDateLabel");
        text = [nativeDateLabel respondsToSelector:@selector(text)] ? [nativeDateLabel text] : nil;
    }
    if (text.length > 0 && gCurrentLockController) {
        ASDateLabel(gCurrentLockController).text = text;
    }
}

static void ASPrefsChanged(CFNotificationCenterRef center,
                           void *observer,
                           CFStringRef name,
                           const void *object,
                           CFDictionaryRef userInfo) {
    (void)center;
    (void)observer;
    (void)name;
    (void)object;
    (void)userInfo;

    dispatch_async(dispatch_get_main_queue(), ^{
        BOOL oldLS = gLockScreenEnabled;
        ASLoadPreferences();

        id dateView = gCurrentDateView;
        id controller = gCurrentLockController;
        if (dateView) {
            ASSetOriginalDateViewHidden(dateView, gLockScreenEnabled);
            if (gLockScreenEnabled) ASUpdateDateFromDateView(dateView);
        }
        if (controller) {
            if (gLockScreenEnabled) {
                ASInstallLockClock(controller);
            } else if (oldLS) {
                ASSetLockClockHidden(controller, YES);
                ASStopClockTimer(controller);
            }
        }
    });
}

%group StatusBar

%hook UIStatusBarTimeItemView
- (id)contentsImage {
    if (!gStatusBarEnabled) return %orig;

    NSString *timeString = ASSafeValueForKey(self, @"_timeString");
    if (![timeString isKindOfClass:[NSString class]] ||
        [[timeString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] length] == 0) {
        return %orig;
    }

    UIColor *textColor = nil;
    if ([self respondsToSelector:@selector(foregroundStyle)]) {
        id style = [(id)self foregroundStyle];
        if ([style respondsToSelector:@selector(textColorForStyle:)] &&
            [self respondsToSelector:@selector(legibilityStyle)]) {
            textColor = [style textColorForStyle:[(id)self legibilityStyle]];
        }
    }

    CGFloat white = 1.0, alpha = 1.0;
    [textColor getWhite:&white alpha:&alpha];
    UIColor *clockColor = white >= 0.5 ? [UIColor whiteColor] : [UIColor blackColor];
    UIImage *image = ASAnalogClockImage(13.0, clockColor, 3.4, 4.45, 1.0, nil);
    if (!image) return %orig;

    Class imageSetClass = NSClassFromString(@"_UILegibilityImageSet");
    if ([imageSetClass respondsToSelector:@selector(imageFromImage:withShadowImage:)]) {
        return [imageSetClass imageFromImage:image withShadowImage:image];
    }
    return %orig;
}
%end

%hook UIStatusBarLayoutManager
- (CGRect)_frameForItemView:(UIView *)itemView startPosition:(CGFloat)startPosition {
    CGRect frame = %orig;
    Class timeClass = NSClassFromString(@"UIStatusBarTimeItemView");
    if (gStatusBarEnabled && timeClass && [itemView isKindOfClass:timeClass]) {
        frame.size.width = 20.0;
    }
    return frame;
}
%end

%end

%group LockScreenController

%hook SBLockScreenViewController
- (void)viewDidLoad {
    %orig;
    gCurrentLockController = self;
    if (gLockScreenEnabled) ASInstallLockClock(self);
}

- (void)viewWillAppear:(BOOL)animated {
    %orig;
    gCurrentLockController = self;
    if (gLockScreenEnabled) ASInstallLockClock(self);
}

- (void)viewDidDisappear:(BOOL)animated {
    ASStopClockTimer(self);
    %orig;
}

- (BOOL)_shouldShowChargingText {
    if (gLockScreenEnabled) return NO;
    return %orig;
}

- (void)_addBatteryChargingViewAndShowBattery:(BOOL)showBattery {
    if (gLockScreenEnabled) {
        objc_setAssociatedObject(self, ASChargingHiddenKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        ASSetLockClockHidden(self, YES);
    }
    %orig;
}

- (void)_removeBatteryChargingView {
    %orig;
    objc_setAssociatedObject(self, ASChargingHiddenKey, @NO, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (gLockScreenEnabled) ASApplyLockLayout(self, YES);
}
%end

%end

%group LockScreenDateView

%hook SBFLockScreenDateView
- (void)layoutSubviews {
    %orig;
    gCurrentDateView = self;
    ASSetOriginalDateViewHidden(self, gLockScreenEnabled);
    if (gLockScreenEnabled) ASUpdateDateFromDateView(self);
}
%end

%end

%ctor {
    @autoreleasepool {
        ASLoadPreferences();
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                        NULL,
                                        ASPrefsChanged,
                                        ASPrefsChangedNotification,
                                        NULL,
                                        CFNotificationSuspensionBehaviorDeliverImmediately);

        if (objc_getClass("UIStatusBarTimeItemView") && objc_getClass("UIStatusBarLayoutManager")) {
            %init(StatusBar);
        }

        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
        if ([bundleID isEqualToString:@"com.apple.springboard"]) {
            if (objc_getClass("SBLockScreenViewController")) {
                %init(LockScreenController);
            }
            if (objc_getClass("SBFLockScreenDateView")) {
                %init(LockScreenDateView);
            }
        }
    }
}
