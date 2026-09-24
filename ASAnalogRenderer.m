#import "ASAnalogRenderer.h"
#import <dispatch/dispatch.h>

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

    CGSize size = CGSizeMake(diameter, diameter);
    UIGraphicsBeginImageContextWithOptions(size, NO, 0.0);

    const CGPoint center = CGPointMake(diameter * 0.5, diameter * 0.5);
    const CGFloat circleInset = lineWidth * 0.5;
    UIBezierPath *circle = [UIBezierPath bezierPathWithOvalInRect:CGRectInset((CGRect){CGPointZero, size},
                                                                              circleInset,
                                                                              circleInset)];
    circle.lineWidth = lineWidth;
    [color setStroke];
    [circle stroke];

    const CGFloat hourFraction = (fmod((double)hour, 12.0) + ((double)minute / 60.0)) / 12.0;
    const CGFloat minuteFraction = (double)minute / 60.0;
    const CGFloat hourAngle = (CGFloat)(hourFraction * M_PI * 2.0 - M_PI_2);
    const CGFloat minuteAngle = (CGFloat)(minuteFraction * M_PI * 2.0 - M_PI_2);

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
    [minuteHand stroke];

    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    if (image) [ASClockCache() setObject:image forKey:cacheKey];
    return image;
}

void ASClearAnalogClockCache(void) {
    [ASClockCache() removeAllObjects];
}
