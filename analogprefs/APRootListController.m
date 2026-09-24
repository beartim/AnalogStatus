#import "APRootListController.h"
#import <CoreFoundation/CoreFoundation.h>
#import <objc/runtime.h>
#include <stdlib.h>

static const void *kAPSpecifiersKey = &kAPSpecifiersKey;

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
