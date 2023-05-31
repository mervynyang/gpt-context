#import <Foundation/Foundation.h>

@interface SvLogger : NSObject

+ (void)enableLog:(BOOL)enable;
+ (BOOL)isLogEnabled;

@end

#define SvLog(fmt, ...)                                 \
    do {                                                \
        if ([SvLogger isLogEnabled])                    \
            NSLog((@"MurSurvey: " fmt), ##__VA_ARGS__); \
    } while (0)
