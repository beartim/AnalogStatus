#import <UIKit/UIKit.h>

// Minimal iOS 9-compatible declaration. We intentionally avoid importing the
// current Theos Preferences headers because they use Objective-C syntax newer
// than the legacy Linux iOS clang used for this armv7 + arm64 build.
@interface PSListController : UIViewController
- (NSArray *)loadSpecifiersFromPlistName:(NSString *)name target:(id)target;
@end

@interface APRootListController : PSListController
- (void)respring;
@end
