#import "APRootListController.h"
#import <CoreFoundation/CoreFoundation.h>
#import <objc/runtime.h>
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>

static Ivar APSpecifiersIvar(void) {
    static Ivar ivar = NULL;
    static BOOL didLookup = NO;

    if (!didLookup) {
        Class listControllerClass = NSClassFromString(@"PSListController");
        if (listControllerClass) {
            ivar = class_getInstanceVariable(listControllerClass, "_specifiers");
        }
        didLookup = YES;
    }

    return ivar;
}

static NSArray *APReadSpecifiers(id controller, Ivar ivar) {
    if (!controller || !ivar) return nil;

    ptrdiff_t offset = ivar_getOffset(ivar);
    uint8_t *objectBytes = (uint8_t *)(__bridge void *)controller;
    id __strong *slot = (id __strong *)(objectBytes + offset);
    return *slot;
}

static void APWriteSpecifiers(id controller, Ivar ivar, NSArray *specifiers) {
    if (!controller || !ivar) return;

    ptrdiff_t offset = ivar_getOffset(ivar);
    uint8_t *objectBytes = (uint8_t *)(__bridge void *)controller;
    id __strong *slot = (id __strong *)(objectBytes + offset);
    *slot = specifiers;
}

@implementation APRootListController

- (NSArray *)specifiers {
    /*
     * iOS 9 Preferences.framework still uses PSListController's real
     * _specifiers ivar internally while constructing and displaying the table.
     * Caching the array only in an associated object makes -specifiers return a
     * valid array while the framework itself continues to see _specifiers ==
     * nil, producing an empty preference page on iOS 9.2.
     *
     * Resolve the ivar by name at runtime so we do not hard-code its offset or
     * require modern Theos Preferences headers.  This keeps the armv7/iOS 9
     * build compatible while matching PSListController's expected storage.
     */
    Ivar ivar = APSpecifiersIvar();
    NSArray *specifiers = APReadSpecifiers(self, ivar);

    if (!specifiers) {
        specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
        if (specifiers && ivar) {
            APWriteSpecifiers(self, ivar, specifiers);
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
