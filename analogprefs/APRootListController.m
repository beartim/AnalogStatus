#import "APRootListController.h"
#import <CoreFoundation/CoreFoundation.h>
#import <objc/runtime.h>
#include <stdlib.h>

static const void *kAPSpecifiersKey = &kAPSpecifiersKey;

static void APStoreSpecifiersInPSListController(id controller, NSArray *specifiers) {
    if (!controller || !specifiers) return;

    /*
     * On iOS 9, PSListController's table implementation still reads its
     * private _specifiers ivar directly.  KVC for the key "specifiers" uses a
     * setter when available, otherwise it falls back to the inherited
     * _specifiers ivar.  That gives Preferences.framework the storage it
     * expects without hard-coding an ivar offset or importing newer private
     * headers that the legacy toolchain cannot parse.
     */
    @try {
        [controller setValue:specifiers forKey:@"specifiers"];
    } @catch (__unused NSException *exception) {
        /*
         * Keep -specifiers functional even if a future Preferences.framework
         * removes the KVC-compatible backing ivar.  AnalogStatus only targets
         * iOS 7-9, where _specifiers is present.
         */
    }
}

@implementation APRootListController

- (NSArray *)specifiers {
    NSArray *specifiers = objc_getAssociatedObject(self, kAPSpecifiersKey);

    if (!specifiers) {
        specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
        if (specifiers) {
            objc_setAssociatedObject(self,
                                     kAPSpecifiersKey,
                                     specifiers,
                                     OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            APStoreSpecifiersInPSListController(self, specifiers);
        }
    }

    return specifiers;
}

- (void)respring {
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                         CFSTR("com.faz.analogprefs/ReloadPrefs"),
                                         NULL,
                                         NULL,
                                         YES);
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    system("killall -9 SpringBoard");
#pragma clang diagnostic pop
}

@end
