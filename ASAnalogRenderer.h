#import <UIKit/UIKit.h>

#ifdef __cplusplus
extern "C" {
#endif

UIImage *ASAnalogClockImage(CGFloat diameter,
                            UIColor *color,
                            CGFloat hourHandLength,
                            CGFloat minuteHandLength,
                            CGFloat lineWidth,
                            NSDate *date);

void ASClearAnalogClockCache(void);

#ifdef __cplusplus
}
#endif
