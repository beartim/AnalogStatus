#import "ASAnalogRenderer.h"
#import <dispatch/dispatch.h>
#include <math.h>

static NSCache *ASClockCache(void) {
    static NSCache *cache;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cache = [NSCache new];
        cache.countLimit = 24;
    });
    return cache;
}

static NSString *ASColorKey(UIColor *color) {
    CGFloat white = 0.0, alpha = 1.0;
    if ([color getWhite:&white alpha:&alpha]) {
        return [NSString stringWithFormat:@"w%.3f-a%.3f", white, alpha];
    }

    CGFloat r = 0.0, g = 0.0, b = 0.0;
    if ([color getRed:&r green:&g blue:&b alpha:&alpha]) {
        return [NSString stringWithFormat:@"r%.3f-g%.3f-b%.3f-a%.3f", r, g, b, alpha];
    }
    return color.description ?: @"color";
}

UIImage *ASAnalogClockImage(CGFloat diameter,
                            UIColor *color,
                            CGFloat hourHandLength,
                            CGFloat minuteHandLength,
                            CGFloat lineWidth,
                            NSDate *date) {
    if (diameter <= 0.0 || lineWidth <= 0.0) return nil;
    if (!date) date = [NSDate date];
    if (!color) color = [UIColor whiteColor];

    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDateComponents *parts = [calendar components:(NSCalendarUnitHour | NSCalendarUnitMinute)
                                           fromDate:date];
    NSInteger hour = parts.hour;
    NSInteger minute = parts.minute;

    NSString *cacheKey = [NSString stringWithFormat:@"%ld:%ld|%.2f|%.2f|%.2f|%.2f|%@",
                          (long)hour, (long)minute, diameter, hourHandLength,
                          minuteHandLength, lineWidth, ASColorKey(color)];
    UIImage *cached = [ASClockCache() objectForKey:cacheKey];
    if (cached) return cached;

    /*
     * Preserve the geometry used by AnalogStatus 1.3-4.  The old selector
     * called this value "clockRadius", but it was used as the oval's width
     * and height.  Its bitmap was slightly larger than that oval:
     *
     *   canvas = diameter + lineWidth + 1
     *   oval   = (lineWidth - 0.5, lineWidth - 0.5, diameter, diameter)
     *
     * The hand origin intentionally remains diameter / 2 rather than the
     * geometric center of the offset oval.  This small asymmetry is visible
     * in the original binary and is retained for visual fidelity.
     */
    const CGFloat canvasEdge = diameter + lineWidth + 1.0;
    const CGSize size = CGSizeMake(canvasEdge, canvasEdge);
    const CGFloat scale = [UIScreen mainScreen].scale;
    UIGraphicsBeginImageContextWithOptions(size, NO, scale);

    UIBezierPath *circle = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(lineWidth - 0.5,
                                                                             lineWidth - 0.5,
                                                                             diameter,
                                                                             diameter)];
    circle.lineWidth = lineWidth;
    [color setStroke];
    [circle stroke];

    const CGPoint center = CGPointMake(diameter * 0.5, diameter * 0.5);
    const CGFloat minuteFraction = (CGFloat)minute / 60.0;
    const CGFloat hourFraction = (CGFloat)fmod((double)hour, 12.0) / 12.0;

    /*
     * Keep the original 1.3-4 hand-angle math.  In particular, its hour-hand
     * minute compensation is minuteFraction / 1.9 rather than the exact
     * minuteFraction * (2*pi/12).  The values are close, but matching the old
     * formula avoids a subtle visual drift from the historical package.
     */
    const CGFloat hourAngle = hourFraction * (CGFloat)(M_PI * 2.0)
                            - (CGFloat)M_PI_2
                            + minuteFraction / 1.9;
    const CGFloat minuteAngle = minuteFraction * (CGFloat)(M_PI * 2.0)
                              - (CGFloat)M_PI_2;

    UIBezierPath *hourHand = [UIBezierPath bezierPath];
    hourHand.lineCapStyle = kCGLineCapRound;
    hourHand.lineWidth = lineWidth;
    [hourHand moveToPoint:center];
    [hourHand addLineToPoint:CGPointMake(center.x + cos(hourAngle) * hourHandLength,
                                         center.y + sin(hourAngle) * hourHandLength)];
    [color setStroke];
    [hourHand stroke];

    UIBezierPath *minuteHand = [UIBezierPath bezierPath];
    minuteHand.lineCapStyle = kCGLineCapRound;
    minuteHand.lineWidth = lineWidth;
    [minuteHand moveToPoint:center];
    [minuteHand addLineToPoint:CGPointMake(center.x + cos(minuteAngle) * minuteHandLength,
                                           center.y + sin(minuteAngle) * minuteHandLength)];
    [color setStroke];
    [minuteHand stroke];

    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    if (image) [ASClockCache() setObject:image forKey:cacheKey];
    return image;
}

void ASClearAnalogClockCache(void) {
    [ASClockCache() removeAllObjects];
}
